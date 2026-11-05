import 'dart:convert';

import '../core/http.dart';
import '../models/account.dart';
import '../models/audio.dart';
import '../models/models.dart';
import 'bluesky.dart';
import 'funkwhale.dart';
import 'lemmy.dart';
import 'mastodon.dart';

/// Ações em nome de uma conta conectada. Cada método recebe a conta já com
/// token válido; renovar sessão expirada fica a cargo de quem chama.
class AccountApi {
  AccountApi._();

  static final _api = Api.instance;

  // --- Linha do tempo -------------------------------------------------------

  static Future<Page<Post>> home(Account a, String? cursor) async {
    switch (a.kind) {
      case AccountKind.funkwhale:
        return const Page([]);
      case AccountKind.mastodon:
        final data = await _api.send(
          'GET',
          'https://${a.server}/api/v1/timelines/home',
          bearer: a.token,
          query: {'limit': '30', 'max_id': ?cursor},
        ) as List;
        return Page([
          for (final s in data) MastodonApi.parseStatus(s as Map, a.server),
        ], data.isEmpty ? null : '${(data.last as Map)['id']}');
      case AccountKind.bluesky:
        final data = await _api.send(
          'GET',
          '${a.server}/xrpc/app.bsky.feed.getTimeline',
          bearer: a.token,
          query: {'limit': '30', 'cursor': ?cursor},
        );
        return Page(
          BlueskyApi.parseFeed(data['feed']),
          data['cursor'] as String?,
        );
      case AccountKind.lemmy:
        final page = int.tryParse(cursor ?? '') ?? 1;
        final data = await _api.send(
          'GET',
          'https://${a.server}/api/v3/post/list',
          bearer: a.token,
          query: {
            'type_': 'Subscribed',
            'sort': 'Active',
            'limit': '20',
            'page': '$page',
          },
        );
        final posts = (data['posts'] as List).cast<Map>();
        return Page([
          for (final p in posts) LemmyApi.parsePost(p, a.server),
        ], posts.isEmpty ? null : '${page + 1}');
    }
  }

  // --- Curtir / compartilhar ------------------------------------------------

  static Future<void> like(Account a, Post p) => switch (a.kind) {
    AccountKind.mastodon => _mastodonStatusAction(a, p, 'favourite'),
    AccountKind.bluesky => _bskyRecord(a, 'app.bsky.feed.like', {
      'subject': {'uri': p.ref, 'cid': p.cid},
    }),
    AccountKind.lemmy => _lemmyVote(a, p),
    AccountKind.funkwhale => throw ApiException(
      'Use uma conta do Mastodon para curtir posts',
    ),
  };

  static Future<void> boost(Account a, Post p) => switch (a.kind) {
    AccountKind.mastodon => _mastodonStatusAction(a, p, 'reblog'),
    AccountKind.bluesky => _bskyRecord(a, 'app.bsky.feed.repost', {
      'subject': {'uri': p.ref, 'cid': p.cid},
    }),
    AccountKind.lemmy => throw ApiException('O Lemmy não tem compartilhamento'),
    AccountKind.funkwhale => throw ApiException(
      'Use uma conta do Mastodon para compartilhar',
    ),
  };

  static Future<void> _mastodonStatusAction(
    Account a,
    Post p,
    String action,
  ) async {
    final id = await _localStatusId(a, p);
    await _api.send(
      'POST',
      'https://${a.server}/api/v1/statuses/$id/$action',
      bearer: a.token,
    );
  }

  /// Posts vindos de outro servidor precisam ser "puxados" para o servidor da
  /// conta antes de qualquer ação; a busca com `resolve=true` faz isso.
  static Future<String> _localStatusId(Account a, Post p) async {
    if (p.instance == a.server &&
        p.network != Network.lemmy &&
        p.network != Network.peertube) {
      return p.id;
    }
    final url = p.url;
    if (url == null) throw ApiException('Post sem endereço público');
    final r = await _api.send(
      'GET',
      'https://${a.server}/api/v2/search',
      bearer: a.token,
      query: {'q': url, 'resolve': 'true', 'type': 'statuses', 'limit': '1'},
    );
    final list = r['statuses'] as List;
    if (list.isEmpty) {
      throw ApiException('Seu servidor não encontrou este post');
    }
    return '${(list.first as Map)['id']}';
  }

  static Future<void> _lemmyVote(Account a, Post p) async {
    final r = await _api.send(
      'GET',
      'https://${a.server}/api/v3/resolve_object',
      bearer: a.token,
      query: {'q': p.url ?? ''},
    );
    final id = r['post']?['post']?['id'];
    if (id == null) throw ApiException('Seu servidor não encontrou este post');
    await _api.send(
      'POST',
      'https://${a.server}/api/v3/post/like',
      bearer: a.token,
      json: {'post_id': id, 'score': 1},
    );
  }

  // --- Seguir ---------------------------------------------------------------

  static Future<void> followPerson(Account a, Author who) async {
    switch (a.kind) {
      case AccountKind.mastodon:
        final r = await _api.send(
          'GET',
          'https://${a.server}/api/v2/search',
          bearer: a.token,
          query: {
            'q': '@${who.handle}',
            'resolve': 'true',
            'type': 'accounts',
            'limit': '1',
          },
        );
        final list = r['accounts'] as List;
        if (list.isEmpty) {
          throw ApiException('Seu servidor não encontrou @${who.handle}');
        }
        await _api.send(
          'POST',
          'https://${a.server}/api/v1/accounts/${(list.first as Map)['id']}/follow',
          bearer: a.token,
        );
      case AccountKind.bluesky:
        await _bskyRecord(a, 'app.bsky.graph.follow', {'subject': who.id});
      case AccountKind.lemmy:
        throw ApiException('No Lemmy você segue comunidades, não pessoas');
      case AccountKind.funkwhale:
        throw ApiException('Use uma conta do Mastodon para seguir pessoas');
    }
  }

  static Future<void> joinCommunity(Account a, Community c) async {
    switch (a.kind) {
      case AccountKind.lemmy:
        final r = await _api.send(
          'GET',
          'https://${a.server}/api/v3/resolve_object',
          bearer: a.token,
          query: {'q': c.url ?? ''},
        );
        final id = r['community']?['community']?['id'];
        if (id == null) {
          throw ApiException('Seu servidor não encontrou a comunidade');
        }
        await _api.send(
          'POST',
          'https://${a.server}/api/v3/community/follow',
          bearer: a.token,
          json: {'community_id': id, 'follow': true},
        );
      case AccountKind.mastodon:
        // Grupos do Lemmy também podem ser seguidos como contas pelo Mastodon.
        await followPerson(
          a,
          Author(
            id: c.name,
            name: c.displayTitle,
            handle: c.name,
            network: Network.lemmy,
          ),
        );
      case AccountKind.bluesky:
        throw ApiException('Comunidades do Lemmy não chegam ao Bluesky');
      case AccountKind.funkwhale:
        throw ApiException('Use uma conta do Lemmy ou do Mastodon');
    }
  }

  // --- Publicar -------------------------------------------------------------

  /// Publica um post de texto; devolve a URL pública quando disponível.
  static Future<String?> post(Account a, String text) async {
    switch (a.kind) {
      case AccountKind.mastodon:
        final r = await _api.send(
          'POST',
          'https://${a.server}/api/v1/statuses',
          bearer: a.token,
          json: {'status': text, 'visibility': 'public', 'language': 'pt'},
        );
        return r['url'] as String?;
      case AccountKind.bluesky:
        final r = await _bskyRecord(a, 'app.bsky.feed.post', {
          'text': text,
          'langs': ['pt'],
          if (_facets(text).isNotEmpty) 'facets': _facets(text),
        });
        final rkey = '${r['uri']}'.split('/').last;
        return 'https://bsky.app/profile/${a.handle}/post/$rkey';
      case AccountKind.lemmy:
        throw ApiException('No Lemmy os posts vão para uma comunidade');
      case AccountKind.funkwhale:
        throw ApiException('O Funkwhale publica músicas, não posts de texto');
    }
  }

  static Future<Map> _bskyRecord(
    Account a,
    String collection,
    Map<String, Object?> record,
  ) async {
    final r = await _api.send(
      'POST',
      '${a.server}/xrpc/com.atproto.repo.createRecord',
      bearer: a.token,
      json: {
        'repo': a.userId,
        'collection': collection,
        'record': {
          r'$type': collection,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          ...record,
        },
      },
    );
    return r as Map;
  }

  /// Links e hashtags no Bluesky precisam de "facets" com posições em bytes UTF-8.
  static List<Map<String, Object>> _facets(String text) {
    final out = <Map<String, Object>>[];
    int byteAt(int i) => utf8.encode(text.substring(0, i)).length;
    for (final m in RegExp(r'https?://[^\s]+').allMatches(text)) {
      final url = m[0]!.replaceAll(RegExp(r'[.,;:!?)]+$'), '');
      out.add({
        'index': {
          'byteStart': byteAt(m.start),
          'byteEnd': byteAt(m.start + url.length),
        },
        'features': [
          {r'$type': 'app.bsky.richtext.facet#link', 'uri': url},
        ],
      });
    }
    for (final m in RegExp(
      r'(^|\s)(#[\p{L}\p{N}_]+)',
      unicode: true,
    ).allMatches(text)) {
      final start = m.start + m[1]!.length;
      out.add({
        'index': {'byteStart': byteAt(start), 'byteEnd': byteAt(m.end)},
        'features': [
          {r'$type': 'app.bsky.richtext.facet#tag', 'tag': m[2]!.substring(1)},
        ],
      });
    }
    return out;
  }
}

/// Ações de música com conta Funkwhale.
class FunkwhaleAccountApi {
  FunkwhaleAccountApi._();

  static final _api = Api.instance;

  /// Favorita a faixa. Se ela estiver em outro pod, pede ao servidor da conta
  /// que a busque pela federação antes.
  static Future<void> favorite(Account a, AudioItem t) async {
    var id = t.host == a.server ? t.trackId : null;
    if (id == null) {
      if (t.fid == null) {
        throw ApiException(
          'Esta faixa não pode ser trazida para o seu servidor',
        );
      }
      var fetch = await _api.send(
        'POST',
        'https://${a.server}/api/v1/federation/fetches/',
        bearer: a.token,
        json: {'object': t.fid},
      );
      for (var i = 0; i < 8 && fetch['status'] == 'pending'; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        fetch = await _api.send(
          'GET',
          'https://${a.server}/api/v1/federation/fetches/${fetch['id']}/',
          bearer: a.token,
        );
      }
      final obj = fetch['object'];
      id = obj is Map && obj['type'] == 'track' ? obj['id'] as int? : null;
      if (id == null) {
        throw ApiException(
          'Seu servidor não conseguiu trazer esta faixa de ${t.host}',
        );
      }
    }
    await _api.send(
      'POST',
      'https://${a.server}/api/v1/favorites/tracks/',
      bearer: a.token,
      json: {'track': id},
    );
  }

  static Future<List<AudioItem>> favorites(Account a) async {
    final data = await _api.send(
      'GET',
      'https://${a.server}/api/v1/favorites/tracks/',
      bearer: a.token,
      query: {'page_size': '50'},
    );
    return [
      for (final f in data['results'] as List)
        if (f is Map && f['track'] is Map)
          ?FunkwhaleApi.parseTrack(
            f['track'] as Map,
            a.server,
            bearer: a.token,
          ),
    ];
  }
}
