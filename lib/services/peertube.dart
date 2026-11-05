import '../core/http.dart';
import '../models/models.dart';

/// PeerTube: vídeos federados. A busca global usa o Sepia Search, que indexa
/// centenas de instâncias.
class PeerTubeApi {
  PeerTubeApi._();

  static const _sepia = 'https://sepiasearch.org/api/v1';
  static final _api = Api.instance;

  static Future<Page<Post>> search({
    String? query,
    String sort = '-trending',
    int start = 0,
    int count = 24,
    List<String> languages = const [],
  }) async {
    final data = await _api.get(
      '$_sepia/search/videos',
      query: {
        'start': '$start',
        'count': '$count',
        'sort': query == null || query.isEmpty ? sort : '-match',
        'nsfw': 'false',
        'isLive': 'false',
        if (query != null && query.isNotEmpty) 'search': query,
        if (languages.isNotEmpty) 'languageOneOf': languages.join(','),
      },
    );
    final items = [
      for (final v in data['data'] as List)
        if (v is Map) _video(v),
    ];
    final total = data['total'] as int? ?? 0;
    return Page(items, start + count < total ? '${start + count}' : null);
  }

  static Future<List<Community>> searchChannels(String query) async {
    final data = await _api.get(
      '$_sepia/search/video-channels',
      query: {'search': query, 'count': '12'},
    );
    return [
      for (final c in data['data'] as List)
        if (c is Map)
          Community(
            id: '${c['name']}@${c['host']}',
            kind: CommunityKind.channel,
            network: Network.peertube,
            name: '${c['name']}@${c['host']}',
            title: c['displayName'] as String?,
            description: c['description'] as String?,
            avatar:
                _firstImage(c['avatars']) ??
                (c['avatar'] as Map?)?['url'] as String?,
            banner: _firstImage(c['banners']),
            members: c['followersCount'] as int?,
            url: c['url'] as String?,
            instance: c['host'] as String?,
          ),
    ];
  }

  static Future<Page<Post>> channelVideos(
    Community channel, {
    int start = 0,
  }) async {
    final host = channel.instance!;
    final name = channel.name.split('@').first;
    final data = await _api.get(
      'https://$host/api/v1/video-channels/$name/videos',
      query: {'start': '$start', 'count': '24', 'sort': '-publishedAt'},
    );
    final items = [
      for (final v in data['data'] as List)
        if (v is Map) _video(v, host: host),
    ];
    final total = data['total'] as int? ?? 0;
    return Page(items, start + 24 < total ? '${start + 24}' : null);
  }

  static final _resolved = <String, String>{};

  /// Descobre um arquivo reproduzível para o vídeo (MP4 próximo de 720p, ou HLS).
  static Future<String> playableUrl(Post video) async {
    final ref = video.ref!;
    final cached = _resolved[ref];
    if (cached != null) return cached;
    final slash = ref.indexOf('/');
    final host = ref.substring(0, slash);
    final uuid = ref.substring(slash + 1);
    final v = await _api.get('https://$host/api/v1/videos/$uuid');

    // Arquivos MP4 "web video" e os MP4 fragmentados de cada playlist HLS:
    // ambos tocam em qualquer player (o HLS puro não toca no Chrome).
    final playlists = (v['streamingPlaylists'] as List? ?? const [])
        .cast<Map>();
    final files = <Map>[
      ...(v['files'] as List? ?? const []).cast<Map>(),
      for (final p in playlists)
        ...(p['files'] as List? ?? const []).cast<Map>(),
    ].where((f) => (f['resolution']?['id'] as int? ?? 0) > 0).toList();
    String? url;
    if (files.isNotEmpty) {
      int score(Map f) => ((f['resolution']['id'] as int) - 720).abs();
      files.sort((a, b) => score(a).compareTo(score(b)));
      url =
          (files.first['fileUrl'] ?? files.first['fileDownloadUrl']) as String?;
    }
    if (url == null && playlists.isNotEmpty) {
      url = playlists.first['playlistUrl'] as String?;
    }
    if (url == null) throw ApiException('Vídeo sem arquivo reproduzível');
    return _resolved[ref] = url;
  }

  // ---------------------------------------------------------------------------

  static String? _firstImage(dynamic list) {
    if (list is! List || list.isEmpty) return null;
    final sorted = [...list.cast<Map>()]
      ..sort(
        (a, b) =>
            ((b['width'] as int? ?? 0)).compareTo(a['width'] as int? ?? 0),
      );
    return sorted.first['fileUrl'] as String? ??
        sorted.first['path'] as String?;
  }

  static Post _video(Map v, {String? host}) {
    final url = v['url'] as String? ?? '';
    final h =
        host ??
        Uri.tryParse(url)?.host ??
        (v['channel'] as Map?)?['host'] as String? ??
        '';
    final account = v['account'] as Map? ?? const {};
    final channel = v['channel'] as Map? ?? account;
    String? abs(String? path) => path == null
        ? null
        : (path.startsWith('http') ? path : 'https://$h$path');
    final aspect = double.tryParse('${v['aspectRatio']}');
    final preview =
        abs(v['previewUrl'] as String?) ??
        abs(v['previewPath'] as String?) ??
        abs(v['thumbnailUrl'] as String?) ??
        abs(v['thumbnailPath'] as String?);
    final avatar =
        _firstImage(channel['avatars']) ??
        (channel['avatar'] as Map?)?['url'] as String? ??
        abs((channel['avatar'] as Map?)?['path'] as String?);

    return Post(
      id: v['uuid'] as String,
      ref: '$h/${v['uuid']}',
      network: Network.peertube,
      author: Author(
        id: '${channel['name']}@${channel['host'] ?? h}',
        name: channel['displayName'] as String? ?? '',
        handle: '${channel['name']}@${channel['host'] ?? h}',
        network: Network.peertube,
        avatar: abs(avatar),
        url: channel['url'] as String?,
      ),
      createdAt:
          DateTime.tryParse(v['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      title: v['name'] as String?,
      text:
          v['truncatedDescription'] as String? ??
          v['description'] as String? ??
          '',
      media: [
        Media(
          type: MediaType.video,
          url: '',
          previewUrl: preview,
          aspect: aspect != null && aspect > 0 ? aspect : 16 / 9,
          alt: '${v['duration'] ?? 0}',
        ),
      ],
      likes: v['likes'] as int? ?? 0,
      replies: v['comments'] as int? ?? 0,
      views: v['views'] as int?,
      url: url,
      instance: h,
      tags: [for (final t in v['tags'] as List? ?? const []) '$t'],
      sensitive: v['nsfw'] as bool? ?? false,
    );
  }
}
