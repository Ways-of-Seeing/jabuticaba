/// Modelos unificados: cada rede do fediverso é traduzida para estes tipos,
/// para que a interface não precise saber de onde o conteúdo veio.
library;

enum Network {
  mastodon('Mastodon'),
  bluesky('Bluesky'),
  pixelfed('Pixelfed'),
  peertube('PeerTube'),
  loops('Loops'),
  funkwhale('Funkwhale'),
  castopod('Castopod'),
  lemmy('Lemmy');

  const Network(this.label);
  final String label;
}

class Author {
  const Author({
    required this.id,
    required this.name,
    required this.handle,
    required this.network,
    this.avatar,
    this.url,
    this.bio,
    this.banner,
    this.followers,
    this.following,
    this.posts,
  });

  final String id;
  final String name;

  /// Identificador completo, ex.: `user@mastodon.social` ou `user.bsky.social`.
  final String handle;
  final Network network;
  final String? avatar;
  final String? url;
  final String? bio;
  final String? banner;
  final int? followers;
  final int? following;
  final int? posts;

  String get displayName => name.trim().isEmpty ? handle : name;
}

enum MediaType { image, video, gifv }

class Media {
  const Media({
    required this.type,
    required this.url,
    this.previewUrl,
    this.aspect,
    this.blurhash,
    this.alt,
  });

  final MediaType type;
  final String url;
  final String? previewUrl;

  /// Largura / altura. `null` quando desconhecido.
  final double? aspect;
  final String? blurhash;
  final String? alt;

  bool get isVideo => type == MediaType.video || type == MediaType.gifv;
  String get thumb => previewUrl ?? url;
}

class LinkCard {
  const LinkCard({
    required this.url,
    required this.title,
    this.description,
    this.image,
    this.provider,
    this.blurhash,
  });

  final String url;
  final String title;
  final String? description;
  final String? image;
  final String? provider;
  final String? blurhash;
}

class Post {
  const Post({
    required this.id,
    required this.network,
    required this.author,
    required this.createdAt,
    this.text = '',
    this.html,
    this.title,
    this.media = const [],
    this.likes = 0,
    this.reposts = 0,
    this.replies = 0,
    this.views,
    this.url,
    this.instance,
    this.tags = const [],
    this.card,
    this.community,
    this.sensitive = false,
    this.spoiler,
    this.ref,
    this.cid,
    this.boostedBy,
  });

  final String id;
  final Network network;
  final Author author;
  final DateTime createdAt;
  final String text;

  /// Conteúdo HTML (Mastodon/Pixelfed). Quando presente, tem prioridade sobre [text].
  final String? html;

  /// Título (posts do Lemmy, vídeos do PeerTube).
  final String? title;
  final List<Media> media;
  final int likes;
  final int reposts;
  final int replies;
  final int? views;
  final String? url;

  /// Servidor de onde lemos o post (necessário para buscar respostas).
  final String? instance;
  final List<String> tags;
  final LinkCard? card;
  final Community? community;
  final bool sensitive;
  final String? spoiler;

  /// Referência específica da rede: URI `at://` no Bluesky, UUID no PeerTube.
  final String? ref;

  /// CID do registro no Bluesky (necessário para curtir e repostar).
  final String? cid;
  final Author? boostedBy;

  bool get hasVideo => media.any((m) => m.isVideo);
  bool get hasImage => media.any((m) => m.type == MediaType.image);
  String get key => '${network.name}:$id';
}

enum CommunityKind {
  server('Servidor'),
  group('Comunidade'),
  feed('Feed'),
  channel('Canal'),
  hashtag('Hashtag'),
  person('Perfil'),
  podcast('Podcast');

  const CommunityKind(this.label);
  final String label;
}

class Community {
  const Community({
    required this.id,
    required this.kind,
    required this.network,
    required this.name,
    this.title,
    this.description,
    this.avatar,
    this.banner,
    this.members,
    this.activeMembers,
    this.url,
    this.language,
    this.category,
    this.instance,
    this.blurhash,
    this.approvalRequired = false,
  });

  final String id;
  final CommunityKind kind;
  final Network network;

  /// Nome técnico: domínio do servidor, `!comunidade@instancia`, URI do feed…
  final String name;
  final String? title;
  final String? description;
  final String? avatar;
  final String? banner;
  final int? members;
  final int? activeMembers;
  final String? url;
  final String? language;
  final String? category;
  final String? instance;
  final String? blurhash;
  final bool approvalRequired;

  String get displayTitle =>
      (title?.trim().isNotEmpty ?? false) ? title! : name;
  String get key => '${network.name}:${kind.name}:$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'network': network.name,
    'name': name,
    'title': title,
    'description': description,
    'avatar': avatar,
    'banner': banner,
    'members': members,
    'url': url,
    'instance': instance,
  };

  factory Community.fromJson(Map<String, dynamic> j) => Community(
    id: j['id'] as String,
    kind: CommunityKind.values.byName(j['kind'] as String),
    network: Network.values.byName(j['network'] as String),
    name: j['name'] as String,
    title: j['title'] as String?,
    description: j['description'] as String?,
    avatar: j['avatar'] as String?,
    banner: j['banner'] as String?,
    members: j['members'] as int?,
    url: j['url'] as String?,
    instance: j['instance'] as String?,
  );
}

class Trend {
  const Trend({
    required this.name,
    required this.network,
    this.uses,
    this.description,
    this.ref,
  });

  final String name;
  final Network network;
  final int? uses;
  final String? description;

  /// Para tendências do Bluesky: a URI do feed do tópico.
  final String? ref;
}

class Reply {
  const Reply({required this.post, this.depth = 0});
  final Post post;
  final int depth;
}

/// Página de resultados com cursor opaco para continuar a paginação.
class Page<T> {
  const Page(this.items, [this.cursor]);
  final List<T> items;
  final String? cursor;
}
