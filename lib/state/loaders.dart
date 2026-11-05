import 'dart:convert';

import '../core/http.dart';
import '../models/models.dart';
import '../services/bluesky.dart';
import '../services/lemmy.dart';
import '../services/loops.dart';
import '../services/mastodon.dart';
import '../services/peertube.dart';
import 'settings.dart';

/// Carrega uma página a partir de um cursor opaco (`null` = primeira página).
typedef Loader<T> = Future<Page<T>> Function(String? cursor);

/// Combina vários carregadores num só fio intercalado. O cursor composto é um
/// JSON com o cursor de cada fonte; fontes esgotadas ou com erro saem da mistura.
Loader<Post> mix(
  Map<String, Loader<Post>> sources, {
  bool Function(Post)? where,
}) {
  return (cursor) async {
    final current = cursor == null
        ? {for (final k in sources.keys) k: null}
        : Map<String, String?>.from(jsonDecode(cursor) as Map);
    final entries = await Future.wait([
      for (final e in current.entries)
        if (sources[e.key] != null)
          sources[e.key]!(e.value)
              // Uma instância lenta não pode segurar o fio inteiro.
              .timeout(const Duration(seconds: 10))
              .then<MapEntry<String, Page<Post>>?>((p) => MapEntry(e.key, p))
              .catchError((_) => null),
    ]);
    final next = <String, String?>{};
    final lists = <List<Post>>[];
    for (final e in entries) {
      if (e == null) continue;
      lists.add(
        where == null ? e.value.items : e.value.items.where(where).toList(),
      );
      if (e.value.cursor != null) next[e.key] = e.value.cursor;
    }
    return Page(interleave(lists), next.isEmpty ? null : jsonEncode(next));
  };
}

/// Envolve uma fonte que não pagina (devolve tudo de uma vez).
Loader<Post> once(Future<List<Post>> Function() f) =>
    (cursor) async => cursor == null ? Page(await f()) : const Page([]);

Loader<Post> mastodonTrends([String instance = MastodonApi.defaultInstance]) =>
    (c) async {
      final offset = int.tryParse(c ?? '') ?? 0;
      final items = await MastodonApi.trendingStatuses(
        instance: instance,
        offset: offset,
      );
      return Page(
        items,
        items.isEmpty || offset > 60 ? null : '${offset + items.length}',
      );
    };

Loader<Post> mastodonTag(String tag, {bool media = false}) =>
    (c) => MastodonApi.tagTimeline(tag, maxId: c, onlyMedia: media);

Loader<Post> blueskyFeed([String uri = BlueskyApi.discover]) =>
    (c) => BlueskyApi.feed(uri, cursor: c);

Loader<Post> lemmyHot({String? community, String sort = 'Hot'}) =>
    (c) => LemmyApi.posts(
      community: community,
      sort: sort,
      page: int.tryParse(c ?? '') ?? 1,
    );

Loader<Post> peertube({String? query, List<String> languages = const []}) =>
    (c) => PeerTubeApi.search(
      query: query,
      start: int.tryParse(c ?? '') ?? 0,
      languages: languages,
    );

Loader<Post> loopsTag(String tag) =>
    (c) => LoopsApi.tagFeed(tag, cursor: c);

final _accountCache = <String, (Author, String)>{};

/// Posts de uma conta do Mastodon/Pixelfed a partir do `user@servidor`.
Loader<Post> accountLoader(String acct, {bool media = false}) => (c) async {
  final found = _accountCache[acct] ??= await MastodonApi.lookup(acct);
  return MastodonApi.accountStatuses(
    found.$1.id,
    instance: found.$2,
    maxId: c,
    onlyMedia: media,
  );
};

Loader<Post> authorLoader(Author a, {bool media = false}) =>
    switch (a.network) {
      Network.bluesky => (c) => BlueskyApi.authorFeed(
        a.handle,
        cursor: c,
        media: media,
      ),
      Network.loops => (c) => LoopsApi.accountFeed(a.id, cursor: c),
      Network.peertube => communityLoader(
        Community(
          id: a.handle,
          kind: CommunityKind.channel,
          network: Network.peertube,
          name: a.handle,
          instance: a.handle.split('@').last,
        ),
      ),
      Network.lemmy => once(() async => const []),
      _ => accountLoader(a.handle, media: media),
    };

Loader<Post> communityLoader(Community c) => switch (c.kind) {
  CommunityKind.server => (cur) async {
    try {
      return await MastodonApi.localTimeline(c.instance ?? c.name, maxId: cur);
    } catch (_) {
      // Muitos servidores fecham a linha do tempo local para visitantes;
      // as tendências do servidor costumam continuar abertas.
      return mastodonTrends(c.instance ?? c.name)(cur);
    }
  },
  CommunityKind.group => lemmyHot(community: c.name),
  CommunityKind.feed => blueskyFeed(c.name),
  CommunityKind.channel => (cur) => PeerTubeApi.channelVideos(
    c,
    start: int.tryParse(cur ?? '') ?? 0,
  ),
  CommunityKind.hashtag => mix({
    'masto': mastodonTag(c.name),
    'loops': loopsTag(c.name),
  }),
  CommunityKind.person => authorLoader(
    Author(id: c.id, name: c.title ?? '', handle: c.name, network: c.network),
  ),
  // Podcasts do Castopod são contas do fediverso: os episódios chegam como posts.
  CommunityKind.podcast => accountLoader(c.name),
};

// --- Fios principais --------------------------------------------------------

enum FioSource {
  /// Linhas do tempo das contas conectadas (montada pelo AccountsNotifier).
  home('Minhas contas'),
  all('Para você'),
  following('Seguindo'),
  mastodon('Mastodon'),
  bluesky('Bluesky'),
  lemmy('Lemmy');

  const FioSource(this.label);
  final String label;
}

Loader<Post> fioLoader(FioSource source, Settings s) => switch (source) {
  FioSource.home => once(() async => const []),
  FioSource.all => mix({
    'masto': mastodonTrends(),
    'bsky': blueskyFeed(),
    for (final t in s.interestTags.take(3)) 'tag:$t': mastodonTag(t),
    'lemmy': lemmyHot(),
  }),
  FioSource.following =>
    s.follows.isEmpty
        ? once(() async => const [])
        : mix({for (final f in s.follows.take(12)) f.key: communityLoader(f)}),
  FioSource.mastodon => mix({
    'trends': mastodonTrends(),
    for (final t in s.interestTags.take(4)) 'tag:$t': mastodonTag(t),
  }),
  FioSource.bluesky => blueskyFeed(),
  FioSource.lemmy => lemmyHot(),
};

/// Tags que costumam existir no Loops, usadas como fallback de interesses.
const _loopsTags = [
  'fyp',
  'music',
  'art',
  'nature',
  'funny',
  'gaming',
  'travel',
  'loops',
];

Loader<Post> clipsLoader(Settings s) {
  final tags = {
    for (final i in s.chosen) i.query,
    ..._loopsTags.take(4),
  }.take(5);
  return mix({
    'loops': once(() => LoopsApi.publicFeed()),
    for (final t in tags) 'loops:$t': loopsTag(t),
    'peertube': peertube(),
    'bsky': blueskyFeed(),
    'masto': mastodonTrends(),
  }, where: (p) => p.hasVideo && !p.sensitive);
}

Loader<Post> photosLoader(Settings s) => mix({
  'pixelfed': once(() => PixelfedApi.trending()),
  'pixelfed:m': once(() => PixelfedApi.trending(range: 'monthly')),
  'masto:photo': mastodonTag('photography', media: true),
  for (final i in s.chosen.take(3))
    'masto:${i.tags.first}': mastodonTag(i.tags.first, media: true),
  'bsky': blueskyFeed(),
}, where: (p) => p.hasImage && !p.sensitive);

Future<List<T>> safe<T>(Future<List<T>> f) => f.catchError((_) => <T>[]);
