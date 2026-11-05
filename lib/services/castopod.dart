import 'package:xml/xml.dart';

import '../core/format.dart';
import '../core/http.dart';
import '../models/audio.dart';
import '../models/models.dart';

/// Podcasts do Castopod. A lista vem do Castopod Index (que reúne os feeds do
/// PodcastIndex gerados pelo Castopod); os episódios vêm do RSS de cada um.
class CastopodApi {
  CastopodApi._();

  /// Pode apontar para um espelho com `--dart-define=CASTOPOD_INDEX=...`
  /// (útil na versão web, já que o índice oficial não libera CORS).
  static const _index = String.fromEnvironment(
    'CASTOPOD_INDEX',
    defaultValue: 'https://index.castopod.org/podcastindex.json',
  );
  static List<Show>? _cache;

  /// Prefixo de um proxy para os feeds RSS (`--dart-define=FEED_PROXY=...`),
  /// que recebe a URL do feed codificada. Só faz falta na web: os servidores
  /// de podcast não liberam CORS.
  static const _feedProxy = String.fromEnvironment('FEED_PROXY');

  /// ~2 mil podcasts (4 MB): baixa uma vez por sessão.
  static Future<List<Show>> index() async {
    if (_cache != null) return _cache!;
    final data = await Api.instance.get(_index) as List;
    final shows = <Show>[];
    // O índice repete alguns podcasts (mesmo endereço, caixa diferente).
    final seen = <String>{};
    for (final p in data) {
      if (p is! Map ||
          _int(p['dead']) == 1 ||
          _int(p['lastHttpStatus']) != 200) {
        continue;
      }
      final feed = (p['url'] ?? p['originalUrl']) as String?;
      if (feed == null) continue;
      final title = (p['title'] as String? ?? '').trim();
      if (title.isEmpty) continue;
      if (!seen.add('${p['link'] ?? feed}'.toLowerCase())) continue;
      final last = _int(p['newestItemPubdate']);
      final latestUrl = p['newestEnclosureUrl'] as String?;
      final show = Show(
        id: '${p['id']}',
        title: title,
        feedUrl: feed,
        author: (p['itunesAuthor'] ?? p['ownerName'] ?? '') as String,
        artwork: p['imageUrl'] as String?,
        description: htmlToText(p['description'] as String?),
        link: p['link'] as String?,
        language: (p['language'] as String?)?.toLowerCase().split('-').first,
        categories: [
          for (var i = 1; i <= 10; i++)
            if ((p['category$i'] as String? ?? '').isNotEmpty)
              p['category$i'] as String,
        ],
        episodes: _int(p['episodeCount']),
        popularity: _int(p['popularityScore']) ?? 0,
        lastEpisodeAt: last == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(last * 1000),
      );
      shows.add(
        Show(
          id: show.id,
          title: show.title,
          feedUrl: show.feedUrl,
          author: show.author,
          artwork: show.artwork,
          description: show.description,
          link: show.link,
          language: show.language,
          categories: show.categories,
          episodes: show.episodes,
          popularity: show.popularity,
          lastEpisodeAt: show.lastEpisodeAt,
          latest: latestUrl == null
              ? null
              : AudioItem(
                  id: latestUrl,
                  title: 'Episódio mais recente',
                  artist: show.title,
                  streamUrl: latestUrl,
                  network: Network.castopod,
                  artwork: show.artwork,
                  duration: (_int(p['newestEnclosureDuration'])) == null
                      ? null
                      : Duration(seconds: _int(p['newestEnclosureDuration'])!),
                  url: show.link,
                  host: show.host,
                  publishedAt: show.lastEpisodeAt,
                  uploaderHandle: show.handle,
                  episode: true,
                ),
        ),
      );
    }
    return _cache = shows;
  }

  /// Episódios do feed RSS, do mais novo para o mais antigo.
  static Future<(Show, List<AudioItem>)> feed(Show show) async {
    final res = await Api.instance.text(
      _feedProxy.isEmpty
          ? show.feedUrl
          : '$_feedProxy${Uri.encodeComponent(show.feedUrl)}',
    );
    final doc = XmlDocument.parse(res);
    final channel = doc.findAllElements('channel').first;
    String? text(XmlElement e, String name) {
      final found =
          e.findElements(name).firstOrNull ??
          e.findAllElements(name).firstOrNull;
      final t = found?.innerText.trim();
      return t == null || t.isEmpty ? null : t;
    }

    String? image(XmlElement e) =>
        e.findElements('itunes:image').firstOrNull?.getAttribute('href') ??
        e
            .findElements('image')
            .firstOrNull
            ?.findElements('url')
            .firstOrNull
            ?.innerText;

    final art = image(channel) ?? show.artwork;
    final items = <AudioItem>[];
    for (final it in channel.findElements('item')) {
      final enc = it.findElements('enclosure').firstOrNull;
      final src = enc?.getAttribute('url');
      if (src == null) continue;
      items.add(
        AudioItem(
          id: text(it, 'guid') ?? src,
          title: text(it, 'title') ?? 'Episódio',
          artist: show.title,
          streamUrl: src,
          network: Network.castopod,
          artwork: image(it) ?? art,
          duration: _duration(text(it, 'itunes:duration')),
          url: text(it, 'link') ?? show.link,
          host: show.host,
          publishedAt: _rfc822(text(it, 'pubDate')),
          description: htmlToText(
            text(it, 'description') ?? text(it, 'itunes:summary'),
          ),
          uploaderHandle: show.handle,
          episode: true,
        ),
      );
    }
    final full = Show(
      id: show.id,
      title: text(channel, 'title') ?? show.title,
      feedUrl: show.feedUrl,
      author: text(channel, 'itunes:author') ?? show.author,
      artwork: art,
      description: text(channel, 'description') == null
          ? show.description
          : htmlToText(text(channel, 'description')),
      link: text(channel, 'link') ?? show.link,
      language: show.language,
      categories: show.categories,
      episodes: items.length,
      popularity: show.popularity,
      lastEpisodeAt: items.isEmpty
          ? show.lastEpisodeAt
          : items.first.publishedAt,
    );
    return (full, items);
  }

  static int? _int(dynamic v) => v is int ? v : int.tryParse('${v ?? ''}');

  static Duration? _duration(String? s) {
    if (s == null) return null;
    final parts = s.split(':').map(int.tryParse).toList();
    if (parts.any((p) => p == null)) return null;
    var secs = 0;
    for (final p in parts) {
      secs = secs * 60 + p!;
    }
    return Duration(seconds: secs);
  }

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  /// "Tue, 28 Oct 2026 10:00:00 +0000" → DateTime.
  static DateTime? _rfc822(String? s) {
    if (s == null) return null;
    final m = RegExp(r'(\d{1,2}) (\w{3}) (\d{4}) (\d{2}):(\d{2})(?::(\d{2}))?')
        .firstMatch(s);
    if (m == null) return DateTime.tryParse(s);
    final month = _months[m[2]!.toLowerCase()];
    if (month == null) return null;
    return DateTime.utc(
      int.parse(m[3]!),
      month,
      int.parse(m[1]!),
      int.parse(m[4]!),
      int.parse(m[5]!),
      int.parse(m[6] ?? '0'),
    );
  }
}
