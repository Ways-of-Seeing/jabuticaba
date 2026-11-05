import '../core/http.dart';
import '../models/models.dart';

/// Loops (loops.video): vídeos curtos verticais federados, no estilo TikTok/Reels.
class LoopsApi {
  LoopsApi._();

  static const defaultInstance = 'loops.video';
  static final _api = Api.instance;

  /// O feed público devolve poucos vídeos embaralhados por chamada; fazemos
  /// algumas chamadas e removemos repetidos.
  static Future<List<Post>> publicFeed({
    String instance = defaultInstance,
    int rounds = 3,
  }) async {
    final batches = await gatherLists([
      for (var i = 0; i < rounds; i++)
        _api
            .get('https://$instance/api/web/feed?r=$i', cache: false)
            .then((d) => _videos(d, instance)),
    ]);
    final seen = <String>{};
    return [
      for (final p in batches)
        if (seen.add(p.id)) p,
    ];
  }

  static Future<List<Trend>> trendingTags({
    String instance = defaultInstance,
  }) async {
    final data = await _api.get('https://$instance/api/v1/explore/tags');
    return [
      for (final t in data['data'] as List)
        Trend(
          name: t['name'] as String,
          network: Network.loops,
          uses: t['count'] as int?,
        ),
    ];
  }

  static Future<Page<Post>> tagFeed(
    String tag, {
    String instance = defaultInstance,
    String? cursor,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/explore/tag-feed/${Uri.encodeComponent(tag)}',
      query: {'limit': '20', 'cursor': ?cursor},
    );
    return Page(
      _videos(data, instance),
      (data['meta'] as Map?)?['next_cursor'] as String?,
    );
  }

  static Future<Page<Post>> accountFeed(
    String accountId, {
    String instance = defaultInstance,
    String? cursor,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v1/feed/account/$accountId',
      query: {'cursor': ?cursor},
    );
    return Page(
      _videos(data, instance),
      (data['meta'] as Map?)?['next_cursor'] as String?,
    );
  }

  // ---------------------------------------------------------------------------

  static List<Post> _videos(dynamic data, String instance) => [
    for (final v in (data is Map ? data['data'] : data) as List? ?? const [])
      if (v is Map && v['media'] is Map && v['is_sensitive'] != true)
        _video(v, instance),
  ];

  static Post _video(Map v, String instance) {
    final a = v['account'] as Map? ?? const {};
    final m = v['media'] as Map;
    final w = m['width'] as num?, h = m['height'] as num?;
    final src = (m['hls_url'] ?? m['src_url']) as String?;
    return Post(
      id: '${v['id']}',
      network: Network.loops,
      author: Author(
        id: '${a['id']}',
        name: a['display_name'] as String? ?? a['name'] as String? ?? '',
        handle: '${a['username']}@$instance',
        network: Network.loops,
        avatar: a['avatar'] as String?,
        url: 'https://$instance/@${a['username']}',
      ),
      createdAt:
          DateTime.tryParse(v['created_at'] as String? ?? '') ?? DateTime.now(),
      text: v['caption'] as String? ?? '',
      media: [
        if (src != null)
          Media(
            type: MediaType.video,
            url: src,
            previewUrl: m['thumbnail'] as String?,
            aspect: w != null && h != null && h > 0 ? w / h : 9 / 16,
            alt: m['alt_text'] as String?,
          ),
      ],
      likes: v['likes'] as int? ?? 0,
      reposts: v['shares'] as int? ?? 0,
      replies: v['comments'] as int? ?? 0,
      url: v['url'] as String?,
      instance: instance,
      tags: [for (final t in v['tags'] as List? ?? const []) '$t'],
    );
  }
}
