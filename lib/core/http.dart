import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, [this.status, this.body]);
  final String message;
  final int? status;

  /// Corpo da resposta de erro (JSON decodificado, quando houver).
  final Object? body;
  @override
  String toString() => 'ApiException($status): $message';
}

/// Cliente HTTP compartilhado com cache curto em memória, para que voltar a uma
/// tela não refaça todas as requisições.
class Api {
  Api._();
  static final instance = Api._();

  final _client = http.Client();

  /// LRU pequeno: feeds paginados não podem ficar retidos para sempre.
  final _cache = <String, _CacheEntry>{};
  final _inflight = <String, Future<dynamic>>{};
  var _cacheBytes = 0;
  static const _ttl = Duration(minutes: 3);
  static const _maxEntries = 150;
  static const _maxBytes = 8 << 20;
  static const _maxEntryBytes = 512 << 10;

  /// Na web o navegador manda o próprio User-Agent. Enviar outro faz o
  /// WebKit pedir um preflight CORS que vários servidores não respondem.
  static const _headers = {
    if (!kIsWeb) 'User-Agent': 'jabuticaba/0.1 (+https://jabuticaba.social)',
    'Accept': 'application/json',
  };

  Future<dynamic> get(
    String url, {
    Map<String, String>? query,
    bool cache = true,
  }) {
    final uri = Uri.parse(
      url,
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final key = 'json:$uri';
    final hit = _hit(key);
    if (cache && hit != null) return Future.value(hit);

    // Explorar e Fio pedem algumas das mesmas URLs ao mesmo tempo.
    final pending = _inflight[key];
    if (cache && pending != null) return pending;
    final future = _fetchJson(uri, key, cache: cache);
    if (!cache) return future;
    _inflight[key] = future;
    return future.whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    });
  }

  Future<dynamic> _fetchJson(Uri uri, String key, {required bool cache}) async {
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('GET $uri falhou', res.statusCode);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (cache) _put(key, data, res.bodyBytes.length);
    return data;
  }

  /// Requisição autenticada/sem cache. `json` vira corpo JSON; `form` vira
  /// corpo application/x-www-form-urlencoded.
  Future<dynamic> send(
    String method,
    String url, {
    String? bearer,
    Map<String, String>? query,
    Object? json,
    Map<String, String>? form,
    Map<String, String>? headers,
  }) async {
    final uri = Uri.parse(
      url,
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final req = http.Request(method, uri)
      ..headers.addAll(_headers)
      ..headers.addAll(headers ?? const {});
    if (bearer != null) req.headers['Authorization'] = 'Bearer $bearer';
    if (json != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(json);
    } else if (form != null) {
      req.bodyFields = form;
    }
    final res = await http.Response.fromStream(
      await _client.send(req).timeout(const Duration(seconds: 30)),
    );
    final text = utf8.decode(res.bodyBytes);
    Object? data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        _errorMessage(data) ?? '$method $uri falhou',
        res.statusCode,
        data,
      );
    }
    return data;
  }

  /// Extrai a mensagem de erro dos formatos comuns (Mastodon, atproto, Lemmy).
  static String? _errorMessage(Object? data) {
    if (data is! Map) return null;
    for (final k in ['error_description', 'message', 'error']) {
      final v = data[k];
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  /// GET que devolve o corpo como texto (feeds RSS), com o mesmo cache curto.
  Future<String> text(String url) async {
    final key = 'text:$url';
    final hit = _hit(key);
    if (hit is String) return hit;
    final res = await _client
        .get(Uri.parse(url), headers: {'User-Agent': ?_headers['User-Agent']})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('GET $url falhou', res.statusCode);
    }
    // Um feed malicioso não deve consumir memória sem limite.
    if (res.bodyBytes.length > 8 << 20) {
      throw ApiException('Resposta grande demais (mais de 8 MB)');
    }
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    _put(key, body, res.bodyBytes.length);
    return body;
  }

  Object? _hit(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.storedAt) >= _ttl) {
      _remove(key);
      return null;
    }
    // LinkedHashMap: regravar move a entrada para o fim (mais recente).
    _cache.remove(key);
    _cache[key] = entry;
    return entry.value;
  }

  void _put(String key, Object? value, int bytes) {
    if (bytes > _maxEntryBytes) return;
    _remove(key);
    _cache[key] = _CacheEntry(DateTime.now(), value, bytes);
    _cacheBytes += bytes;
    final expiredBefore = DateTime.now().subtract(_ttl);
    final expired = <String>[];
    for (final entry in _cache.entries) {
      if (entry.value.storedAt.isAfter(expiredBefore)) break;
      expired.add(entry.key);
    }
    expired.forEach(_remove);
    while (_cache.isNotEmpty &&
        (_cache.length > _maxEntries || _cacheBytes > _maxBytes)) {
      _remove(_cache.keys.first);
    }
  }

  void _remove(String key) {
    final removed = _cache.remove(key);
    if (removed != null) _cacheBytes -= removed.bytes;
  }

  void clearCache() {
    _cache.clear();
    _cacheBytes = 0;
  }
}

class _CacheEntry {
  const _CacheEntry(this.storedAt, this.value, this.bytes);
  final DateTime storedAt;
  final Object? value;
  final int bytes;
}

/// Executa [tasks] em paralelo e ignora as que falharem: o fediverso é
/// heterogêneo e uma instância fora do ar não deve derrubar a tela.
Future<List<T>> gatherLists<T>(Iterable<Future<List<T>>> tasks) async {
  final results = await Future.wait(
    tasks.map((t) => t.then<List<T>?>((v) => v).catchError((_) => null)),
  );
  return [for (final r in results) ...?r];
}

/// Intercala listas (a, b, c, a, b, c…) para misturar redes num só fio.
List<T> interleave<T>(List<List<T>> lists) {
  final out = <T>[];
  var i = 0;
  var added = true;
  while (added) {
    added = false;
    for (final l in lists) {
      if (i < l.length) {
        out.add(l[i]);
        added = true;
      }
    }
    i++;
  }
  return out;
}
