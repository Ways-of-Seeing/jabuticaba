import '../core/http.dart';
import '../models/models.dart';

/// API do Mastodon. Também serve Pixelfed (compatível).
///
/// O jabuticaba não integra o Threads nem outros serviços da Meta: posts e
/// contas do threads.net que chegam pela federação são descartados aqui.
class MastodonApi {
  MastodonApi._();

  static const defaultInstance = 'mastodon.social';
  static final _api = Api.instance;

  static Future<List<Post>> trendingStatuses({
    String instance = defaultInstance,
    int offset = 0,
    int limit = 20,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/trends/statuses',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return _statuses(data, instance);
  }

  static Future<List<Trend>> trendingTags({
    String instance = defaultInstance,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/trends/tags',
      query: {'limit': '20'},
    ) as List;
    return [
      for (final t in data)
        Trend(
          name: t['name'] as String,
          network: Network.mastodon,
          uses: _historyUses(t['history']),
        ),
    ];
  }

  static Future<List<LinkCard>> trendingLinks({
    String instance = defaultInstance,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/trends/links',
      query: {'limit': '12'},
    ) as List;
    return [
      for (final l in data)
        LinkCard(
          url: l['url'] as String,
          title: (l['title'] as String? ?? '').trim(),
          description: l['description'] as String?,
          image: l['image'] as String?,
          provider: l['provider_name'] as String?,
          blurhash: l['blurhash'] as String?,
        ),
    ];
  }

  static Future<Page<Post>> tagTimeline(
    String tag, {
    String instance = defaultInstance,
    String? maxId,
    bool onlyMedia = false,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/timelines/tag/${Uri.encodeComponent(tag)}',
      query: {
        'limit': '30',
        'max_id': ?maxId,
        if (onlyMedia) 'only_media': 'true',
      },
    );
    final posts = _statuses(data, instance);
    return Page(
      posts,
      (data as List).isEmpty ? null : data.last['id'] as String,
    );
  }

  static Future<Page<Post>> localTimeline(
    String instance, {
    String? maxId,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/timelines/public',
      query: {'local': 'true', 'limit': '30', 'max_id': ?maxId},
    );
    final posts = _statuses(data, instance);
    return Page(
      posts,
      (data as List).isEmpty ? null : data.last['id'] as String,
    );
  }

  /// Procura a conta no servidor padrão; se ele não a conhecer, pergunta ao
  /// servidor de origem.
  static Future<(Author, String)> lookup(String acct) async {
    final domain = acct.contains('@') ? acct.split('@').last : defaultInstance;
    for (final instance in {defaultInstance, domain}) {
      try {
        final a = await _api.get(
          'https://$instance/api/v1/accounts/lookup',
          query: {'acct': acct},
        );
        return (parseAccount(a as Map, instance), instance);
      } catch (_) {}
    }
    throw ApiException('Conta $acct não encontrada');
  }

  static Future<Page<Post>> accountStatuses(
    String id, {
    required String instance,
    String? maxId,
    bool onlyMedia = false,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/accounts/$id/statuses',
      query: {
        'limit': '30',
        'exclude_replies': 'true',
        if (onlyMedia) 'only_media': 'true',
        'max_id': ?maxId,
      },
    );
    final posts = _statuses(data, instance);
    return Page(
      posts,
      (data as List).isEmpty ? null : data.last['id'] as String,
    );
  }

  static Future<List<Reply>> replies(String id, String instance) async {
    final data = await _api.get(
      'https://$instance/api/v1/statuses/$id/context',
    );
    final desc = (data['descendants'] as List).cast<Map>();
    final depth = <String, int>{id: -1};
    final out = <Reply>[];
    for (final s in desc) {
      if (fromMeta(s)) continue;
      final parent = s['in_reply_to_id'] as String?;
      final d = (depth[parent] ?? -1) + 1;
      depth[s['id'] as String] = d;
      out.add(Reply(post: parseStatus(s, instance), depth: d.clamp(0, 4)));
    }
    return out;
  }

  static Future<(List<Author>, List<Trend>)> search(
    String q, {
    String instance = defaultInstance,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v2/search',
      query: {'q': q, 'limit': '12', 'resolve': 'false'},
    );
    final accounts = [
      for (final a in data['accounts'] as List)
        if (!isMetaAccount((a as Map)['acct'] as String?))
          parseAccount(a, instance),
    ];
    final tags = [
      for (final t in data['hashtags'] as List)
        Trend(
          name: t['name'] as String,
          network: Network.mastodon,
          uses: _historyUses(t['history']),
        ),
    ];
    return (accounts, tags);
  }

  static Future<Community> instanceInfo(String domain) async {
    final i = await _api.get('https://$domain/api/v2/instance');
    return Community(
      id: domain,
      kind: CommunityKind.server,
      network: Network.mastodon,
      name: domain,
      title: i['title'] as String?,
      description: i['description'] as String?,
      banner: (i['thumbnail'] as Map?)?['url'] as String?,
      blurhash: (i['thumbnail'] as Map?)?['blurhash'] as String?,
      activeMembers: (i['usage'] as Map?)?['users']?['active_month'] as int?,
      url: 'https://$domain',
      instance: domain,
      approvalRequired:
          (i['registrations'] as Map?)?['approval_required'] as bool? ?? false,
    );
  }

  // ---------------------------------------------------------------------------

  static List<Post> _statuses(dynamic data, String instance, [Network? net]) =>
      [
        for (final s in data as List)
          if (s is Map && !fromMeta(s)) parseStatus(s, instance, network: net),
      ];

  static const _metaDomains = {'threads.net', 'threads.com'};

  /// Conta hospedada pela Meta (Threads)?
  static bool isMetaAccount(String? acct) =>
      acct != null &&
      _metaDomains.any((d) => acct.toLowerCase().endsWith('@$d'));

  /// Post escrito ou compartilhado por uma conta da Meta.
  static bool fromMeta(Map s) {
    final reblog = s['reblog'];
    return isMetaAccount((s['account'] as Map?)?['acct'] as String?) ||
        (reblog is Map &&
            isMetaAccount((reblog['account'] as Map?)?['acct'] as String?));
  }

  static int? _historyUses(dynamic history) {
    if (history is! List) return null;
    return history.fold<int>(
      0,
      (sum, h) => sum + (int.tryParse('${h['uses']}') ?? 0),
    );
  }

  static Network _networkFor(String acct, Network fallback) {
    if (acct.contains('@pixelfed.')) return Network.pixelfed;
    return fallback;
  }

  static Author parseAccount(Map a, String instance, {Network? network}) {
    var acct = a['acct'] as String? ?? a['username'] as String? ?? '';
    if (!acct.contains('@')) acct = '$acct@$instance';
    return Author(
      id: '${a['id']}',
      name: a['display_name'] as String? ?? '',
      handle: acct,
      network: _networkFor(acct, network ?? Network.mastodon),
      avatar: a['avatar'] as String?,
      url: a['url'] as String?,
      bio: a['note'] as String?,
      banner: a['header'] as String?,
      followers: a['followers_count'] as int?,
      following: a['following_count'] as int?,
      posts: a['statuses_count'] as int?,
    );
  }

  static Post parseStatus(Map raw, String instance, {Network? network}) {
    final reblog = raw['reblog'];
    final s = reblog is Map ? reblog : raw;
    final author = parseAccount(
      s['account'] as Map,
      instance,
      network: network,
    );
    final card = s['card'];
    return Post(
      id: '${s['id']}',
      network: author.network,
      author: author,
      createdAt:
          DateTime.tryParse(s['created_at'] as String? ?? '') ?? DateTime.now(),
      html: s['content'] as String?,
      media: [
        for (final m in (s['media_attachments'] as List? ?? const []))
          if (m is Map && m['url'] != null && m['type'] != 'audio')
            Media(
              type: switch (m['type']) {
                'video' => MediaType.video,
                'gifv' => MediaType.gifv,
                _ => MediaType.image,
              },
              url: m['url'] as String,
              previewUrl: m['preview_url'] as String?,
              aspect: _aspect(m['meta']),
              blurhash: m['blurhash'] as String?,
              alt: m['description'] as String?,
            ),
      ],
      likes: s['favourites_count'] as int? ?? 0,
      reposts: s['reblogs_count'] as int? ?? 0,
      replies: s['replies_count'] as int? ?? s['reply_count'] as int? ?? 0,
      url: s['url'] as String? ?? s['uri'] as String?,
      instance: instance,
      tags: [
        for (final t in (s['tags'] as List? ?? const []))
          if (t is Map) t['name'] as String,
      ],
      card:
          card is Map &&
              card['url'] != null &&
              (card['title'] as String? ?? '').isNotEmpty
          ? LinkCard(
              url: card['url'] as String,
              title: card['title'] as String,
              description: card['description'] as String?,
              image: card['image'] as String?,
              provider: card['provider_name'] as String?,
              blurhash: card['blurhash'] as String?,
            )
          : null,
      sensitive: s['sensitive'] as bool? ?? false,
      spoiler: (s['spoiler_text'] as String?)?.trim().isEmpty ?? true
          ? null
          : s['spoiler_text'] as String,
      boostedBy: reblog is Map
          ? parseAccount(raw['account'] as Map, instance, network: network)
          : null,
    );
  }

  static double? _aspect(dynamic meta) {
    if (meta is! Map) return null;
    for (final k in ['original', 'small']) {
      final m = meta[k];
      if (m is Map) {
        final a = m['aspect'];
        if (a is num && a > 0) return a.toDouble();
        final w = m['width'], h = m['height'];
        if (w is num && h is num && h > 0) return w / h;
      }
    }
    return null;
  }
}

class PixelfedApi {
  PixelfedApi._();

  static const defaultInstance = 'pixelfed.social';

  /// `range`: `daily`, `monthly` ou `yearly`.
  static Future<List<Post>> trending({
    String instance = defaultInstance,
    String range = 'daily',
  }) async {
    final data = await Api.instance.get(
      'https://$instance/api/pixelfed/v2/discover/posts/trending',
      query: {'range': range},
    );
    return [
      for (final s in data as List)
        if (s is Map)
          MastodonApi.parseStatus(s, instance, network: Network.pixelfed),
    ].where((p) => p.media.isNotEmpty).toList();
  }
}
