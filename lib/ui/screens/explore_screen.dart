import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import '../../models/models.dart';
import '../../models/audio.dart';
import '../../state/audio.dart';
import '../../state/explore.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/audio.dart';
import '../widgets/cards.dart';
import '../widgets/matrix_rain.dart';
import 'music_screen.dart';
import 'podcasts_screen.dart';
import 'search_screen.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key, this.onOpenTab});

  /// Permite que "Ver tudo" leve a outra aba (Clipes, Fotos, Comunidades).
  final void Function(int tab)? onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final wide = context.isWide;

    Future<void> refresh() async {
      ref.invalidate(trendsProvider);
      ref.invalidate(exploreClipsProvider);
      ref.invalidate(explorePhotosProvider);
      ref.invalidate(explorePostsProvider);
      ref.invalidate(exploreVideosProvider);
      ref.invalidate(lemmyCommunitiesProvider);
      ref.invalidate(serversProvider);
      ref.invalidate(bskyFeedsProvider);
      ref.invalidate(newsProvider);
      await ref.read(trendsProvider.future);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  if (context.jc.id == JabuThemeId.matrix)
                    const Positioned.fill(child: MatrixRain(opacity: .28)),
                  SafeArea(bottom: false, child: _Hero(wide: wide)),
                ],
              ),
            ),
            if (settings.chosen.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      for (final i in settings.chosen)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Text(i.emoji),
                            label: Text(i.label),
                            onPressed: () => openTag(context, i.tags.first),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: _Trends()),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Clipes',
                emoji: '🎬',
                subtitle: 'Loops, PeerTube e Bluesky',
                action: 'Assistir',
                onAction: () => onOpenTab?.call(2),
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Post>(
                provider: exploreClipsProvider,
                height: 266,
                skeletonWidth: 150,
                builder: (items) => Carousel(
                  height: 266,
                  itemCount: items.length,
                  itemBuilder: (context, i) => ClipThumb(
                    post: items[i],
                    onTap: () => openClips(context, items, i),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Fotos em alta',
                emoji: '📸',
                subtitle: 'Pixelfed e Mastodon',
                action: 'Ver mais',
                onAction: () => onOpenTab?.call(3),
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Post>(
                provider: explorePhotosProvider,
                height: 220,
                skeletonWidth: 180,
                builder: (items) => Carousel(
                  height: 220,
                  spacing: 8,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final m = items[i].media.first;
                    return GestureDetector(
                      onTap: () => openPost(context, items[i]),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: NetImage(
                          m.thumb,
                          blurhash: m.blurhash,
                          width: 180,
                          height: 220,
                          radius: context.jc.radius,
                          cacheWidth: 500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                'Conversas em alta',
                emoji: '💬',
                subtitle: 'Mastodon e Bluesky agora',
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Post>(
                provider: explorePostsProvider,
                height: 230,
                skeletonWidth: 300,
                builder: (items) => Carousel(
                  height: 230,
                  itemCount: items.length,
                  itemBuilder: (context, i) => TalkCard(post: items[i]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Música no fediverso',
                emoji: '🎧',
                subtitle: 'Álbuns novos no Funkwhale',
                action: 'Ouvir',
                onAction: () => onOpenTab?.call(4),
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Album>(
                provider: albumsProvider(null),
                height: 236,
                skeletonWidth: 170,
                builder: (items) => Carousel(
                  height: 236,
                  itemCount: items.length,
                  itemBuilder: (context, i) => CoverTile(
                    image: items[i].artwork,
                    title: items[i].title,
                    subtitle: items[i].artist,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlbumScreen(album: items[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Podcasts em alta',
                emoji: '🎙️',
                subtitle: 'Do Castopod, para ouvir e comentar',
                action: 'Ver todos',
                onAction: () => onOpenTab?.call(5),
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Show>(
                provider: popularShowsProvider,
                height: 250,
                skeletonWidth: 170,
                builder: (items) => Carousel(
                  height: 250,
                  itemCount: items.length,
                  itemBuilder: (context, i) => CoverTile(
                    image: items[i].artwork,
                    title: items[i].title,
                    subtitle: items[i].author,
                    onTap: () => openShow(context, items[i]),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: _FediverseExplainer()),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Comunidades para você',
                emoji: '🫂',
                subtitle: 'Fóruns do Lemmy, no estilo Reddit',
                action: 'Explorar',
                onAction: () => onOpenTab?.call(6),
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Community>(
                provider: lemmyCommunitiesProvider,
                height: 250,
                skeletonWidth: 260,
                builder: (items) => Carousel(
                  height: 250,
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      CommunityCard(community: items[i]),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                'Vídeos do PeerTube',
                emoji: '📺',
                subtitle: 'O YouTube federado',
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Post>(
                provider: exploreVideosProvider,
                height: 250,
                skeletonWidth: 280,
                builder: (items) => Carousel(
                  height: 250,
                  itemCount: items.length,
                  itemBuilder: (context, i) => VideoCard(post: items[i]),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                'Servidores para começar',
                emoji: '🏡',
                subtitle: 'Escolha uma casa no Mastodon',
                action: 'Todos',
                onAction: () => onOpenTab?.call(6),
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Community>(
                provider: serversProvider(null),
                height: 250,
                skeletonWidth: 260,
                builder: (items) => Carousel(
                  height: 250,
                  itemCount: items.length.clamp(0, 16),
                  itemBuilder: (context, i) =>
                      CommunityCard(community: items[i]),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                'Feeds do Bluesky',
                emoji: '🦋',
                subtitle: 'Feeds temáticos criados pela comunidade',
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<Community>(
                provider: bskyFeedsProvider,
                height: 250,
                skeletonWidth: 260,
                builder: (items) => Carousel(
                  height: 250,
                  itemCount: items.length,
                  itemBuilder: (context, i) =>
                      CommunityCard(community: items[i]),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: SectionHeader(
                'Notícias do fediverso',
                emoji: '📰',
                subtitle: 'Os links mais compartilhados hoje',
              ),
            ),
            SliverToBoxAdapter(
              child: _AsyncRow<LinkCard>(
                provider: newsProvider,
                height: 270,
                skeletonWidth: 280,
                builder: (items) => Carousel(
                  height: 270,
                  itemCount: items.length,
                  itemBuilder: (context, i) => NewsCard(card: items[i]),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Boa madrugada';
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, wide ? 28 : 12, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!wide) ...[const Wordmark(size: 22), const SizedBox(height: 22)],
          Text(
            '${_greeting()} 🫐',
            style: context.tt.titleMedium?.copyWith(color: context.jc.muted),
          ),
          const SizedBox(height: 6),
          ShaderMask(
            shaderCallback: (r) => context.jc.accent.createShader(r),
            blendMode: BlendMode.srcIn,
            child: Text(
              'Explore o fediverso',
              style: wide ? context.tt.displayMedium : context.tt.displaySmall,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Vídeos, fotos, conversas e comunidades de redes abertas — tudo num lugar só.',
            style: context.tt.bodyLarge?.copyWith(color: context.jc.muted),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Hero(
              tag: 'search',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: context.jc.r(40),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: context.jc.card,
                      borderRadius: context.jc.r(40),
                      border: Border.all(color: context.jc.line),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, color: context.jc.muted),
                        const SizedBox(width: 10),
                        Text(
                          'Pessoas, hashtags, comunidades, vídeos…',
                          style: TextStyle(color: context.jc.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trends extends ConsumerWidget {
  const _Trends();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trends = ref.watch(trendsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Em alta agora', emoji: '🔥'),
        SizedBox(
          height: 96,
          child: trends.when(
            loading: () => const CarouselSkeleton(height: 40, width: 120),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) {
              // Duas linhas de chips roláveis juntas.
              final rows = [
                for (var i = 0; i < items.length; i += 2) items[i],
                for (var i = 1; i < items.length; i += 2) items[i],
              ];
              final half = (rows.length / 2).ceil();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final t in rows.take(half)) _TrendChip(t),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final t in rows.skip(half)) _TrendChip(t),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip(this.t);
  final Trend t;

  @override
  Widget build(BuildContext context) {
    final color = context.jc.network(t.network);
    final isTopic = t.network == Network.bluesky;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: context.jc.card,
        shape: context.jc.bevel
            ? const Win95Border()
            : context.jc.pill(side: context.jc.line),
        child: InkWell(
          customBorder: context.jc.pill(),
          onTap: () => openTrend(context, t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    isTopic ? t.name : '#${t.name}',
                    style: context.tt.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AsyncRow<T> extends ConsumerWidget {
  const _AsyncRow({
    required this.provider,
    required this.builder,
    required this.height,
    required this.skeletonWidth,
  });

  final ProviderListenable<AsyncValue<List<T>>> provider;
  final Widget Function(List<T> items) builder;
  final double height;
  final double skeletonWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: value.when(
        loading: () => CarouselSkeleton(height: height, width: skeletonWidth),
        error: (e, _) => SizedBox(
          height: 80,
          child: Center(
            child: Text(
              'Esta seção não respondeu agora.',
              style: context.tt.bodySmall,
            ),
          ),
        ),
        data: (items) => items.isEmpty
            ? SizedBox(
                height: 60,
                child: Center(
                  child: Text(
                    'Nada por aqui agora.',
                    style: context.tt.bodySmall,
                  ),
                ),
              )
            : builder(items),
      ),
    );
  }
}

class _FediverseExplainer extends StatelessWidget {
  const _FediverseExplainer();

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // Nos temas da marca o banner é a "casca" da jabuticaba; nos outros,
    // segue o destaque do tema.
    final brand = jc.id == JabuThemeId.jabuticaba || jc.id == JabuThemeId.polpa;
    final fg = brand ? Colors.white : jc.onAccent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: brand
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2A1036),
                    Color(0xFF4B1A55),
                    Color(0xFF7B2D6E),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: jc.r(22),
              )
            : jc.accentPanel(),
        child: Row(
          children: [
            const JabuLogo(size: 54),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Novo no fediverso?',
                    style: context.tt.titleLarge?.copyWith(color: fg),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'São várias redes independentes que conversam entre si — como e-mail, mas social.',
                    style: context.tt.bodyMedium?.copyWith(
                      color: fg.withValues(alpha: .8),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: fg,
                foregroundColor: brand ? jc.brand : jc.accent.colors.first,
              ),
              onPressed: () => showFediverseGuide(context),
              child: const Text('Entender'),
            ),
          ],
        ),
      ),
    );
  }
}

void showFediverseGuide(BuildContext context) {
  const items = [
    (
      Network.mastodon,
      'Mastodon',
      'Conversas em texto, como o antigo Twitter. Milhares de servidores independentes.',
    ),
    (
      Network.bluesky,
      'Bluesky',
      'Rede aberta baseada no AT Protocol, com feeds personalizados.',
    ),
    (
      Network.pixelfed,
      'Pixelfed',
      'Fotos, no estilo Instagram, sem algoritmo de anúncios.',
    ),
    (
      Network.loops,
      'Loops',
      'Vídeos curtos verticais, no estilo TikTok e Reels.',
    ),
    (
      Network.peertube,
      'PeerTube',
      'Vídeos longos, como o YouTube, hospedados por comunidades.',
    ),
    (
      Network.lemmy,
      'Lemmy',
      'Fóruns e comunidades por assunto, como o Reddit.',
    ),
    (
      Network.funkwhale,
      'Funkwhale',
      'Música: artistas independentes publicando álbuns e faixas.',
    ),
    (
      Network.castopod,
      'Castopod',
      'Podcasts que são contas do fediverso: dá para seguir e comentar.',
    ),
  ];
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    constraints: const BoxConstraints(maxWidth: 620),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .8,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text('O fediverso em 1 minuto', style: context.tt.headlineMedium),
          const SizedBox(height: 10),
          Text(
            'Em vez de uma empresa dona de tudo, o fediverso é feito de muitos servidores que conversam por protocolos abertos. '
            'Você escolhe onde morar e continua falando com todo mundo. O jabuticaba junta tudo isso numa só janela — '
            'e dá pra explorar e seguir sem criar conta.',
            style: context.tt.bodyLarge?.copyWith(color: context.jc.muted),
          ),
          const SizedBox(height: 20),
          for (final (net, name, desc) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.jc.network(net).withValues(alpha: .16),
                      borderRadius: context.jc.r(14),
                    ),
                    child: Icon(
                      Jabu.networkIcon(net),
                      color: context.jc.network(net),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: context.tt.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          desc,
                          style: context.tt.bodyMedium?.copyWith(
                            color: context.jc.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
