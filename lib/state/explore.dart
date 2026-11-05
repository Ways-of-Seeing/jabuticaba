import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/http.dart';
import '../models/models.dart';
import '../services/bluesky.dart';
import '../services/directory.dart';
import '../services/lemmy.dart';
import '../services/loops.dart';
import '../services/mastodon.dart';
import '../services/peertube.dart';
import 'loaders.dart';
import 'settings.dart';

/// Hashtags e tópicos em alta, misturando Mastodon, Bluesky e Loops.
final trendsProvider = FutureProvider<List<Trend>>((ref) async {
  final lists = await Future.wait([
    safe(MastodonApi.trendingTags()),
    safe(BlueskyApi.trends()),
    safe(LoopsApi.trendingTags()),
  ]);
  return interleave(lists);
});

final explorePostsProvider = FutureProvider<List<Post>>((ref) async {
  final page = await mix(
    {'masto': mastodonTrends(), 'bsky': blueskyFeed()},
    where: (p) => p.media.isEmpty || p.text.isNotEmpty || p.html != null,
  )(null);
  return page.items.take(16).toList();
});

final exploreClipsProvider = FutureProvider<List<Post>>((ref) async {
  ref.watch(settingsProvider.select((s) => s.interests));
  final page = await clipsLoader(ref.read(settingsProvider))(null);
  return page.items.take(14).toList();
});

final explorePhotosProvider = FutureProvider<List<Post>>((ref) async {
  return safe(PixelfedApi.trending());
});

final exploreVideosProvider = FutureProvider<List<Post>>((ref) async {
  final page = await PeerTubeApi.search(count: 16);
  return page.items;
});

final newsProvider = FutureProvider<List<LinkCard>>(
  (ref) => MastodonApi.trendingLinks(),
);

final lemmyCommunitiesProvider = FutureProvider<List<Community>>(
  (ref) => LemmyApi.communities(limit: 30),
);

final lemmyHotProvider = FutureProvider<List<Post>>((ref) async {
  final page = await LemmyApi.posts();
  return page.items;
});

final bskyFeedsProvider = FutureProvider<List<Community>>((ref) async {
  final page = await BlueskyApi.popularFeeds();
  return page.items;
});

/// Servidores do diretório joinmastodon. `null` = todos; idioma português primeiro.
final serversProvider = FutureProvider.family<List<Community>, String?>((
  ref,
  category,
) async {
  final pt = await safe(
    ServerDirectory.servers(language: 'pt', category: category),
  );
  final all = await safe(ServerDirectory.servers(category: category));
  final seen = <String>{};
  return [
    for (final s in [...pt, ...all])
      if (seen.add(s.id)) s,
  ];
});

final peertubeChannelsProvider = FutureProvider.family<List<Community>, String>(
  (ref, q) => PeerTubeApi.searchChannels(q),
);

class SearchResults {
  const SearchResults({
    this.people = const [],
    this.tags = const [],
    this.communities = const [],
    this.videos = const [],
  });
  final List<Author> people;
  final List<Trend> tags;
  final List<Community> communities;
  final List<Post> videos;

  bool get isEmpty =>
      people.isEmpty && tags.isEmpty && communities.isEmpty && videos.isEmpty;
}

final searchProvider = FutureProvider.family<SearchResults, String>((
  ref,
  q,
) async {
  final query = q.trim();
  if (query.isEmpty) return const SearchResults();
  final tag = query.replaceAll('#', '').replaceAll(' ', '');
  final results = await Future.wait([
    MastodonApi.search(query).catchError((_) => (<Author>[], <Trend>[])),
    safe(BlueskyApi.searchActors(query)),
    safe(LemmyApi.searchCommunities(query)),
    safe(PeerTubeApi.searchChannels(query)),
    safe(BlueskyApi.popularFeeds(query: query).then((p) => p.items)),
    PeerTubeApi.search(
      query: query,
      count: 12,
    ).then((p) => p.items).catchError((_) => <Post>[]),
  ]);
  final masto = results[0] as (List<Author>, List<Trend>);
  final tags = [...masto.$2];
  if (tag.isNotEmpty &&
      !tags.any((t) => t.name.toLowerCase() == tag.toLowerCase())) {
    tags.insert(0, Trend(name: tag, network: Network.mastodon));
  }
  return SearchResults(
    people: interleave([masto.$1, results[1] as List<Author>]),
    tags: tags,
    communities: interleave([
      results[2] as List<Community>,
      results[4] as List<Community>,
      results[3] as List<Community>,
    ]),
    videos: results[5] as List<Post>,
  );
});
