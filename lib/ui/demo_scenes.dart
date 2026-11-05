import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../services/bluesky.dart';
import '../services/funkwhale.dart';
import '../services/loops.dart';
import '../services/mastodon.dart';
import '../state/audio.dart';
import '../state/demo.dart';
import '../state/explore.dart';
import '../state/player.dart';
import 'nav.dart';
import 'screens/explore_screen.dart';
import 'screens/fediverse_screen.dart';
import 'screens/music_screen.dart';
import 'screens/podcasts_screen.dart';
import 'screens/search_screen.dart';
import 'shell.dart';
import 'widgets/account_gate.dart';
import 'widgets/audio.dart';
import 'widgets/theme_picker.dart';

/// Abre a tela pedida em `?tela=` (e `?fediverso=`) no modo demonstração,
/// para que cada parte do app possa ser fotografada sem cliques.
Future<void> runDemoScene(
  BuildContext context,
  WidgetRef ref, {
  required ValueChanged<int> onSelect,
}) async {
  void push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  final fedi = demoParam('fediverso');
  if (fedi != null) {
    final start = FediStart.values.asNameMap()[fedi];
    if (start != null) {
      openFediverse(context, start: start, host: demoParam('servidor'));
    }
    return;
  }

  switch (demoParam('tela')) {
    case 'post':
      final (account, instance) = await MastodonApi.lookup(
        'mastodon@mastodon.social',
      );
      final page = await MastodonApi.accountStatuses(
        account.id,
        instance: instance,
      );
      final post = page.items.firstWhere(
        (p) => p.replies > 0,
        orElse: () => page.items.first,
      );
      if (context.mounted) openPost(context, post);
    case 'perfil':
      openHandle(context, 'mastodon@mastodon.social', Network.mastodon);
    case 'hashtag':
      openTag(context, demoParam('tag') ?? 'photography');
    case 'comunidade':
      openCommunity(
        context,
        const Community(
          id: 'photography@lemmy.world',
          kind: CommunityKind.group,
          network: Network.lemmy,
          name: 'photography@lemmy.world',
          title: 'Photography',
          instance: 'lemmy.world',
          url: 'https://lemmy.world/c/photography',
        ),
      );
    case 'servidor':
      openCommunity(
        context,
        const Community(
          id: 'organica.social',
          kind: CommunityKind.server,
          network: Network.mastodon,
          name: 'organica.social',
          title: 'organica.social',
          instance: 'organica.social',
          url: 'https://organica.social',
        ),
      );
    case 'feed':
      // "For You" e "Discover" pedem login; um feed temático mostra melhor.
      final feeds = (await BlueskyApi.popularFeeds()).items;
      final feed = feeds.firstWhere(
        (f) => RegExp(
          'garden|science|bird|art',
          caseSensitive: false,
        ).hasMatch(f.title ?? ''),
        orElse: () => feeds.first,
      );
      if (context.mounted) openCommunity(context, feed);
    case 'busca':
      push(SearchScreen(initialQuery: demoParam('q') ?? 'fotografia'));
    case 'album':
      final albums = await FunkwhaleApi.albums(FunkwhaleApi.pods.first);
      final withArt = albums.items.where((a) => a.artwork != null).toList()
        ..sort((a, b) => (b.tracks ?? 0).compareTo(a.tracks ?? 0));
      final album = withArt.isEmpty ? albums.items.first : withArt.first;
      if (context.mounted) push(AlbumScreen(album: album));
    case 'podcast':
      // Um programa fora de política e notícias, com capa.
      final shows = await ref.read(popularShowsProvider.future);
      final show = shows.firstWhere(
        (s) =>
            s.artwork != null &&
            !s.categories.any(
              (c) => RegExp(
                'polit|news|notíc|religi|government',
                caseSensitive: false,
              ).hasMatch(c),
            ),
        orElse: () => shows.first,
      );
      if (context.mounted) openShow(context, show);
    case 'player' || 'miniplayer':
      final tracks = await FunkwhaleApi.tracks(FunkwhaleApi.pods.first);
      final withArt = tracks.items.where((t) => t.artwork != null).toList();
      await AudioPlayerService.instance.play(
        withArt.isEmpty ? tracks.items : withArt,
      );
      if (context.mounted && demoParam('tela') == 'player') {
        showFullPlayer(context);
      }
    case 'foto':
      final photos = await ref.read(explorePhotosProvider.future);
      if (context.mounted && photos.isNotEmpty) {
        openMedia(context, photos.first.media, 0);
      }
    case 'clipe':
      final clips = await LoopsApi.publicFeed();
      if (context.mounted && clips.isNotEmpty) openClips(context, clips, 0);
    case 'aviso':
      await showAccountNeeded(
        context,
        ref,
        action: AccountAction.like,
        network: Network.mastodon,
      );
    case 'aviso-musica':
      await showAccountNeeded(
        context,
        ref,
        action: AccountAction.favorite,
        network: Network.funkwhale,
      );
    case 'visual':
      await showThemePicker(context);
    case 'guia':
      showFediverseGuide(context);
    case 'mais':
      showMoreMenu(context, onSelect);
  }
}
