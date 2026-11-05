import 'models.dart';

/// Uma faixa (Funkwhale) ou episódio (Castopod/RSS) que o player toca.
class AudioItem {
  const AudioItem({
    required this.id,
    required this.title,
    required this.artist,
    required this.streamUrl,
    required this.network,
    this.artwork,
    this.album,
    this.duration,
    this.url,
    this.host,
    this.publishedAt,
    this.description,
    this.trackId,
    this.fid,
    this.uploaderHandle,
    this.episode = false,
  });

  final String id;
  final String title;

  /// Artista (música) ou nome do podcast (episódio).
  final String artist;
  final String streamUrl;
  final Network network;
  final String? artwork;
  final String? album;
  final Duration? duration;

  /// Página pública da faixa/episódio.
  final String? url;
  final String? host;
  final DateTime? publishedAt;
  final String? description;

  /// ID numérico da faixa no servidor Funkwhale de origem (para favoritar).
  final int? trackId;

  /// ID federado (ActivityPub) da faixa, para trazê-la a outro servidor.
  final String? fid;

  /// `usuario@servidor` de quem publicou, para seguir pelo fediverso.
  final String? uploaderHandle;
  final bool episode;

  String get key => '${network.name}:$id';
}

/// Álbum do Funkwhale.
class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artist,
    required this.host,
    this.artwork,
    this.tracks,
    this.year,
  });

  final int id;
  final String title;
  final String artist;
  final String host;
  final String? artwork;
  final int? tracks;
  final int? year;

  String get key => '$host:$id';
}

/// Podcast (Castopod Index ou feed RSS).
class Show {
  const Show({
    required this.id,
    required this.title,
    required this.feedUrl,
    this.author = '',
    this.artwork,
    this.description,
    this.link,
    this.language,
    this.categories = const [],
    this.episodes,
    this.popularity = 0,
    this.lastEpisodeAt,
    this.latest,
  });

  final String id;
  final String title;
  final String feedUrl;
  final String author;
  final String? artwork;
  final String? description;

  /// Página do podcast no Castopod (`https://servidor/@podcast`).
  final String? link;
  final String? language;
  final List<String> categories;
  final int? episodes;
  final int popularity;
  final DateTime? lastEpisodeAt;

  /// Episódio mais recente, tocável sem baixar o feed.
  final AudioItem? latest;

  String? get host => link == null ? null : Uri.tryParse(link!)?.host;

  /// Todo podcast do Castopod é uma conta do fediverso: `@podcast@servidor`.
  String? get handle {
    final uri = link == null ? null : Uri.tryParse(link!);
    final seg = uri?.pathSegments.where((s) => s.startsWith('@')).firstOrNull;
    return seg == null ? null : '${seg.substring(1)}@${uri!.host}';
  }

  /// Reconstrói o podcast a partir do que foi salvo em "Seguindo".
  factory Show.fromCommunity(Community c) => Show(
    id: c.id,
    title: c.displayTitle,
    feedUrl: c.instance ?? c.name,
    artwork: c.avatar,
    description: c.description,
    link: c.url,
  );

  Community asCommunity() => Community(
    id: handle ?? feedUrl,
    kind: CommunityKind.podcast,
    network: Network.castopod,
    name: handle ?? feedUrl,
    title: title,
    description: description,
    avatar: artwork,
    url: link,
    instance: feedUrl,
  );
}
