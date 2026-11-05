import '../core/format.dart';
import '../core/http.dart';
import '../models/models.dart';

/// Lemmy: comunidades no estilo fórum (agregador de links e discussões).
class LemmyApi {
  LemmyApi._();

  static const defaultInstance = 'lemmy.world';
  static final _api = Api.instance;
  static final _imageExt = RegExp(
    r'\.(jpe?g|png|webp|gif|avif)(\?.*)?$',
    caseSensitive: false,
  );
  static final _videoExt = RegExp(
    r'\.(mp4|webm|mov)(\?.*)?$',
    caseSensitive: false,
  );

  static Future<Page<Post>> posts({
    String instance = defaultInstance,
    String? community,
    String sort = 'Hot',
    int page = 1,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v3/post/list',
      query: {
        'sort': sort,
        'limit': '20',
        'page': '$page',
        'type_': 'All',
        'community_name': ?community,
      },
    );
    final list = [
      for (final p in data['posts'] as List)
        if (p is Map && p['post']?['nsfw'] != true) _post(p, instance),
    ];
    return Page(list, (data['posts'] as List).isEmpty ? null : '${page + 1}');
  }

  static Future<List<Community>> communities({
    String instance = defaultInstance,
    String sort = 'TopMonth',
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v3/community/list',
      query: {'sort': sort, 'limit': '$limit', 'page': '$page', 'type_': 'All'},
    );
    return [
      for (final c in data['communities'] as List)
        if (c is Map && c['community']?['nsfw'] != true)
          _community(c, instance),
    ];
  }

  static Future<List<Community>> searchCommunities(
    String q, {
    String instance = defaultInstance,
  }) async {
    final data = await _api.get(
      'https://$instance/api/v3/search',
      query: {
        'q': q,
        'type_': 'Communities',
        'sort': 'TopAll',
        'limit': '12',
        'listing_type': 'All',
      },
    );
    return [
      for (final c in data['communities'] as List)
        if (c is Map && c['community']?['nsfw'] != true)
          _community(c, instance),
    ];
  }

  static Future<List<Reply>> comments(String postId, String instance) async {
    final data = await _api.get(
      'https://$instance/api/v3/comment/list',
      query: {
        'post_id': postId,
        'sort': 'Hot',
        'max_depth': '5',
        'limit': '50',
        'type_': 'All',
      },
    );
    final list = (data['comments'] as List).cast<Map>();
    // A API devolve uma árvore achatada; `path` ("0.12.34") dá a profundidade
    // e permite reordenar os filhos logo abaixo dos pais.
    list.sort(
      (a, b) => (a['comment']['path'] as String).compareTo(
        b['comment']['path'] as String,
      ),
    );
    return [
      for (final c in list)
        Reply(
          depth: ((c['comment']['path'] as String).split('.').length - 2).clamp(
            0,
            4,
          ),
          post: Post(
            id: '${c['comment']['id']}',
            network: Network.lemmy,
            author: _author(c['creator'] as Map),
            createdAt: _date(c['comment']['published']),
            text: c['comment']['content'] as String? ?? '',
            likes: c['counts']?['score'] as int? ?? 0,
            replies: c['counts']?['child_count'] as int? ?? 0,
            url: c['comment']['ap_id'] as String?,
            instance: instance,
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------

  static DateTime _date(dynamic s) {
    var str = s as String? ?? '';
    if (str.isNotEmpty && !str.endsWith('Z') && !str.contains('+')) {
      str = '${str}Z';
    }
    return DateTime.tryParse(str) ?? DateTime.now();
  }

  static Author _author(Map c) {
    final host = hostOf(c['actor_id'] as String?);
    return Author(
      id: '${c['id']}',
      name: (c['display_name'] as String?) ?? c['name'] as String? ?? '',
      handle: '${c['name']}@$host',
      network: Network.lemmy,
      avatar: c['avatar'] as String?,
      url: c['actor_id'] as String?,
      bio: c['bio'] as String?,
    );
  }

  static Community _community(Map c, String instance) {
    final co = c['community'] as Map;
    final host = hostOf(co['actor_id'] as String?);
    final counts = c['counts'] as Map? ?? const {};
    return Community(
      id: '${co['name']}@$host',
      kind: CommunityKind.group,
      network: Network.lemmy,
      name: '${co['name']}@$host',
      title: co['title'] as String?,
      description: stripMarkdown(co['description'] as String?),
      avatar: co['icon'] as String?,
      banner: co['banner'] as String?,
      members: counts['subscribers'] as int?,
      activeMembers: counts['users_active_month'] as int?,
      url: co['actor_id'] as String?,
      instance: instance,
    );
  }

  static Post parsePost(Map p, String instance) => _post(p, instance);

  static Post _post(Map p, String instance) {
    final post = p['post'] as Map;
    final url = post['url'] as String?;
    final contentType = post['url_content_type'] as String? ?? '';
    final details = p['image_details'] as Map?;
    double? aspect;
    if (details != null && (details['height'] as num? ?? 0) > 0) {
      aspect = (details['width'] as num) / (details['height'] as num);
    }
    final media = <Media>[];
    LinkCard? card;
    if (url != null &&
        (contentType.startsWith('image') || _imageExt.hasMatch(url))) {
      media.add(
        Media(
          type: MediaType.image,
          url: url,
          previewUrl: post['thumbnail_url'] as String?,
          aspect: aspect,
        ),
      );
    } else if (url != null &&
        (contentType.startsWith('video') || _videoExt.hasMatch(url))) {
      media.add(
        Media(
          type: MediaType.video,
          url: url,
          previewUrl: post['thumbnail_url'] as String?,
          aspect: aspect,
        ),
      );
    } else if (url != null) {
      card = LinkCard(
        url: url,
        title: (post['embed_title'] as String?) ?? hostOf(url),
        description: post['embed_description'] as String?,
        image: post['thumbnail_url'] as String?,
        provider: hostOf(url),
      );
    }
    return Post(
      id: '${post['id']}',
      network: Network.lemmy,
      author: _author(p['creator'] as Map),
      createdAt: _date(post['published']),
      title: post['name'] as String?,
      text: post['body'] as String? ?? '',
      media: media,
      card: card,
      likes: p['counts']?['score'] as int? ?? 0,
      replies: p['counts']?['comments'] as int? ?? 0,
      url: post['ap_id'] as String?,
      instance: instance,
      community: _community({
        'community': p['community'],
        'counts': const {},
      }, instance),
      sensitive: post['nsfw'] as bool? ?? false,
    );
  }
}
