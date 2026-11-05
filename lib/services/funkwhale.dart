import '../core/http.dart';
import '../models/audio.dart';
import '../models/models.dart';

/// Funkwhale: música federada. Cada servidor ("pod") hospeda faixas que podem
/// ser ouvidas sem conta.
class FunkwhaleApi {
  FunkwhaleApi._();

  /// Pods com faixas locais abertas para visitantes (verificado em nov/2026).
  static const pods = [
    'tanukitunes.com',
    'funk.firobe.fr',
    'funkwhale.samtherapy.net',
    'tunez.awadwatt.com',
  ];

  /// Pods com cadastro aberto.
  static const signupPods = [
    'tunez.awadwatt.com',
    'funkwhale.samtherapy.net',
    'stereo.kenobit.it',
  ];

  static final _api = Api.instance;

  static Future<Page<AudioItem>> tracks(
    String host, {
    String? query,
    int page = 1,
    int? album,
  }) async {
    final data = await _api.get(
      'https://$host/api/v1/tracks/',
      query: {
        'page_size': '30',
        'page': '$page',
        'playable': 'true',
        'scope': 'domain:$host',
        if (album == null) 'ordering': '-creation_date',
        if (album != null) ...{
          'album': '$album',
          'ordering': 'disc_number,position',
        },
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return Page([
      for (final t in data['results'] as List)
        if (t is Map) ?_track(t, host),
    ], data['next'] == null ? null : '${page + 1}');
  }

  static Future<Page<Album>> albums(
    String host, {
    String? query,
    int page = 1,
  }) async {
    final data = await _api.get(
      'https://$host/api/v1/albums/',
      query: {
        'page_size': '24',
        'page': '$page',
        'playable': 'true',
        'scope': 'domain:$host',
        'ordering': '-creation_date',
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return Page([
      for (final a in data['results'] as List)
        if (a is Map)
          Album(
            id: a['id'] as int,
            title: a['title'] as String? ?? '',
            artist: (a['artist'] as Map?)?['name'] as String? ?? '',
            host: host,
            artwork: _cover(a['cover']),
            tracks: a['tracks_count'] as int?,
            year: int.tryParse('${a['release_date'] ?? ''}'.split('-').first),
          ),
    ], data['next'] == null ? null : '${page + 1}');
  }

  static String? _cover(dynamic cover) {
    final urls = (cover is Map ? cover['urls'] : null) as Map?;
    return (urls?['large_square_crop'] ??
            urls?['medium_square_crop'] ??
            urls?['original'])
        as String?;
  }

  /// [bearer] entra na URL de áudio quando a faixa só toca com login.
  static AudioItem? parseTrack(Map t, String host, {String? bearer}) {
    final item = _track(t, host);
    if (item == null || bearer == null) return item;
    return AudioItem(
      id: item.id,
      trackId: item.trackId,
      fid: item.fid,
      title: item.title,
      artist: item.artist,
      album: item.album,
      artwork: item.artwork,
      streamUrl:
          '${item.streamUrl}${item.streamUrl.contains('?') ? '&' : '?'}token=$bearer',
      duration: item.duration,
      network: item.network,
      host: item.host,
      url: item.url,
      publishedAt: item.publishedAt,
      uploaderHandle: item.uploaderHandle,
    );
  }

  static AudioItem? _track(Map t, String host) {
    final uploads = (t['uploads'] as List? ?? const []).cast<Map>();
    final listen =
        (uploads.isNotEmpty ? uploads.first['listen_url'] : null) ??
        t['listen_url'];
    if (listen == null) return null;
    final album = t['album'] as Map?;
    final who = t['attributed_to'] as Map?;
    final seconds = uploads.isNotEmpty
        ? uploads.first['duration'] as int?
        : null;
    return AudioItem(
      id: '$host:${t['id']}',
      trackId: t['id'] as int?,
      fid: t['fid'] as String?,
      title: t['title'] as String? ?? '',
      artist: (t['artist'] as Map?)?['name'] as String? ?? '',
      album: album?['title'] as String?,
      artwork: _cover(album?['cover']) ?? _cover(t['cover']),
      streamUrl: '$listen'.startsWith('http')
          ? '$listen'
          : 'https://$host$listen',
      duration: seconds == null ? null : Duration(seconds: seconds),
      network: Network.funkwhale,
      host: host,
      url: 'https://$host/library/tracks/${t['id']}',
      publishedAt: DateTime.tryParse(t['creation_date'] as String? ?? ''),
      uploaderHandle: who == null
          ? null
          : '${who['preferred_username']}@${who['domain'] ?? host}',
    );
  }
}
