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
  final _cache = <String, (DateTime, Object?)>{};
  static const _ttl = Duration(minutes: 3);

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
  }) async {
    final uri = Uri.parse(
      url,
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
    final key = uri.toString();
    final hit = _cache[key];
    if (cache && hit != null && DateTime.now().difference(hit.$1) < _ttl) {
      return hit.$2;
    }
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('GET $uri falhou', res.statusCode);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    _cache[key] = (DateTime.now(), data);
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
    final hit = _cache[url];
    if (hit != null && DateTime.now().difference(hit.$1) < _ttl) {
      return hit.$2 as String;
    }
    final res = await _client
        .get(Uri.parse(url), headers: {'User-Agent': ?_headers['User-Agent']})
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('GET $url falhou', res.statusCode);
    }
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    _cache[url] = (DateTime.now(), body);
    return body;
  }

  void clearCache() => _cache.clear();
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
