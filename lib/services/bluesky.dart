import '../core/http.dart';
import '../models/models.dart';

/// AppView pública do Bluesky (AT Protocol) — leitura sem login.
class BlueskyApi {
  BlueskyApi._();

  static const _base = 'https://public.api.bsky.app/xrpc';
  static const discover =
      'at://did:plc:z72i7hdynmk6r22z27h6tvur/app.bsky.feed.generator/whats-hot';
  static const _sensitiveLabels = {
    'porn',
    'sexual',
    'nudity',
    'graphic-media',
    'gore',
  };
  static final _api = Api.instance;

  static Future<Page<Post>> feed(
    String feedUri, {
    String? cursor,
    int limit = 30,
  }) async {
    final data = await _api.get(
      '$_base/app.bsky.feed.getFeed',
      query: {'feed': feedUri, 'limit': '$limit', 'cursor': ?cursor},
    );
    return Page(_feedItems(data['feed']), data['cursor'] as String?);
  }

  static Future<Page<Post>> authorFeed(
    String actor, {
    String? cursor,
    bool media = false,
  }) async {
    final data = await _api.get(
      '$_base/app.bsky.feed.getAuthorFeed',
      query: {
        'actor': actor,
        'limit': '30',
        'filter': media ? 'posts_with_media' : 'posts_no_replies',
        'cursor': ?cursor,
      },
    );
    return Page(_feedItems(data['feed']), data['cursor'] as String?);
  }

  static Future<Author> profile(String actor) async {
    final p = await _api.get(
      '$_base/app.bsky.actor.getProfile',
      query: {'actor': actor},
    );
    return _author(p as Map);
  }

  static Future<List<Author>> searchActors(String q) async {
    final data = await _api.get(
      '$_base/app.bsky.actor.searchActors',
      query: {'q': q, 'limit': '12'},
    );
    return [for (final a in data['actors'] as List) _author(a as Map)];
  }

  static Future<List<Trend>> trends() async {
    final data = await _api.get('$_base/app.bsky.unspecced.getTrendingTopics');
    return [
      for (final t in data['topics'] as List)
        Trend(
          name: (t['displayName'] ?? t['topic']) as String,
          network: Network.bluesky,
          description: t['description'] as String?,
          ref: _feedLinkToUri(t['link'] as String?),
        ),
    ];
  }

  static Future<Page<Community>> popularFeeds({
    String? cursor,
    String? query,
  }) async {
    final data = await _api.get(
      '$_base/app.bsky.unspecced.getPopularFeedGenerators',
      query: {
        'limit': '25',
        'cursor': ?cursor,
        if (query != null && query.isNotEmpty) 'query': query,
      },
    );
    return Page([
      for (final f in data['feeds'] as List)
        Community(
          id: f['uri'] as String,
          kind: CommunityKind.feed,
          network: Network.bluesky,
          name: f['uri'] as String,
          title: f['displayName'] as String?,
          description: f['description'] as String?,
          avatar: f['avatar'] as String?,
          members: f['likeCount'] as int?,
          instance: (f['creator'] as Map?)?['handle'] as String?,
        ),
    ], data['cursor'] as String?);
  }

  static Future<List<Reply>> replies(String uri) async {
    final data = await _api.get(
      '$_base/app.bsky.feed.getPostThread',
      query: {'uri': uri, 'depth': '4', 'parentHeight': '0'},
    );
    final out = <Reply>[];
    void walk(dynamic node, int depth) {
      for (final r in (node['replies'] as List? ?? const [])) {
        if (r is Map && r['post'] is Map) {
          out.add(
            Reply(post: _post(r['post'] as Map), depth: depth.clamp(0, 4)),
          );
          walk(r, depth + 1);
        }
      }
    }

    walk(data['thread'], 0);
    return out;
  }

  // ---------------------------------------------------------------------------

  /// `/profile/did:plc:x/feed/abc` → `at://did:plc:x/app.bsky.feed.generator/abc`.
  static String? _feedLinkToUri(String? link) {
    final m = RegExp(r'/profile/([^/]+)/feed/([^/?]+)').firstMatch(link ?? '');
    return m == null ? null : 'at://${m[1]}/app.bsky.feed.generator/${m[2]}';
  }

  /// Converte a lista `feed` de getFeed/getTimeline em posts.
  static List<Post> parseFeed(dynamic feed) => _feedItems(feed);

  static List<Post> _feedItems(dynamic feed) {
    final out = <Post>[];
    for (final item in feed as List? ?? const []) {
      if (item is! Map || item['post'] is! Map) continue;
      final reason = item['reason'];
      final post = _post(
        item['post'] as Map,
        boostedBy: reason is Map && reason['by'] is Map
            ? _author(reason['by'] as Map)
            : null,
      );
      out.add(post);
    }
    return out;
  }

  static Author _author(Map a) => Author(
    id: a['did'] as String,
    name: a['displayName'] as String? ?? '',
    handle: a['handle'] as String? ?? '',
    network: Network.bluesky,
    avatar: a['avatar'] as String?,
    url: 'https://bsky.app/profile/${a['handle']}',
    bio: a['description'] as String?,
    banner: a['banner'] as String?,
    followers: a['followersCount'] as int?,
    following: a['followsCount'] as int?,
    posts: a['postsCount'] as int?,
  );

  static Post _post(Map p, {Author? boostedBy}) {
    final author = _author(p['author'] as Map);
    final record = p['record'] as Map? ?? const {};
    final uri = p['uri'] as String;
    final rkey = uri.split('/').last;
    final media = <Media>[];
    LinkCard? card;

    void readEmbed(dynamic e) {
      if (e is! Map) return;
      final type = e[r'$type'] as String? ?? '';
      if (type.startsWith('app.bsky.embed.images')) {
        for (final i in e['images'] as List? ?? const []) {
          media.add(
            Media(
              type: MediaType.image,
              url: i['fullsize'] as String,
              previewUrl: i['thumb'] as String?,
              aspect: _aspect(i['aspectRatio']),
              alt: i['alt'] as String?,
            ),
          );
        }
      } else if (type.startsWith('app.bsky.embed.video')) {
        media.add(
          Media(
            type: MediaType.video,
            url: e['playlist'] as String,
            previewUrl: e['thumbnail'] as String?,
            aspect: _aspect(e['aspectRatio']),
            alt: e['alt'] as String?,
          ),
        );
      } else if (type.startsWith('app.bsky.embed.external')) {
        final x = e['external'] as Map?;
        if (x != null && (x['title'] as String? ?? '').isNotEmpty) {
          card = LinkCard(
            url: x['uri'] as String,
            title: x['title'] as String,
            description: x['description'] as String?,
            image: x['thumb'] as String?,
          );
        }
      } else if (type.startsWith('app.bsky.embed.recordWithMedia')) {
        readEmbed(e['media']);
      }
    }

    readEmbed(p['embed']);

    final tags = <String>{
      for (final f in record['facets'] as List? ?? const [])
        for (final feat in (f as Map)['features'] as List? ?? const [])
          if (feat is Map && feat['tag'] is String) feat['tag'] as String,
    };
    final labels = {
      for (final l in p['labels'] as List? ?? const [])
        (l as Map)['val'] as String?,
    };

    return Post(
      id: uri,
      ref: uri,
      cid: p['cid'] as String?,
      network: Network.bluesky,
      author: author,
      createdAt:
          DateTime.tryParse(record['createdAt'] as String? ?? '') ??
          DateTime.tryParse(p['indexedAt'] as String? ?? '') ??
          DateTime.now(),
      text: record['text'] as String? ?? '',
      media: media,
      card: card,
      likes: p['likeCount'] as int? ?? 0,
      reposts: (p['repostCount'] as int? ?? 0) + (p['quoteCount'] as int? ?? 0),
      replies: p['replyCount'] as int? ?? 0,
      url: 'https://bsky.app/profile/${author.handle}/post/$rkey',
      tags: tags.toList(),
      sensitive: labels.any(_sensitiveLabels.contains),
      boostedBy: boostedBy,
    );
  }

  static double? _aspect(dynamic r) {
    if (r is! Map) return null;
    final w = r['width'], h = r['height'];
    return w is num && h is num && h > 0 ? w / h : null;
  }
}
