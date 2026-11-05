import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/audio.dart';
import '../../models/models.dart';
import '../../state/audio.dart';
import '../../state/player.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/audio.dart';
import '../widgets/audio_actions.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import 'fediverse_screen.dart';

/// Aba "Podcasts": podcasts do Castopod, que são contas do fediverso.
class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen> {
  String? _lang;
  String? _category;
  String _query = '';
  int _shown = 36;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final index = ref.watch(podcastIndexProvider);
    final follows = ref.watch(
      settingsProvider.select(
        (s) => s.follows.where((f) => f.kind == CommunityKind.podcast).toList(),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(jc.headline('Podcasts')),
        toolbarHeight: 64,
        titleTextStyle: context.tt.headlineLarge?.copyWith(
          color: jc.onTitleBar,
        ),
      ),
      body: index.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            MessageView.error(e, () => ref.invalidate(podcastIndexProvider)),
        data: (all) {
          // Português sempre aparece primeiro, mesmo sendo minoria no índice.
          final langs = {
            if (all.any((s) => s.language == 'pt')) 'pt',
            ..._top(all.map((s) => s.language).whereType<String>(), 8),
          }.toList();
          final cats = _top(all.expand((s) => s.categories), 14);
          final q = _query.toLowerCase();
          final filtered = all.where((s) {
            if (_lang != null && s.language != _lang) return false;
            if (_category != null && !s.categories.contains(_category)) {
              return false;
            }
            if (q.isNotEmpty &&
                !'${s.title} ${s.author} ${s.description}'
                    .toLowerCase()
                    .contains(q)) {
              return false;
            }
            return true;
          }).toList();
          final popular = [...filtered]
            ..sort(
              (a, b) => b.popularity != a.popularity
                  ? b.popularity.compareTo(a.popularity)
                  : (b.lastEpisodeAt ?? DateTime(0)).compareTo(
                      a.lastEpisodeAt ?? DateTime(0),
                    ),
            );
          final fresh = filtered.where((s) => s.latest != null).toList()
            ..sort(
              (a, b) => (b.lastEpisodeAt ?? DateTime(0)).compareTo(
                a.lastEpisodeAt ?? DateTime(0),
              ),
            );
          final freshEpisodes = [
            for (final s in fresh.take(12))
              AudioItem(
                id: s.latest!.id,
                title: s.title,
                artist: s.author.isEmpty ? 'Episódio mais recente' : s.author,
                streamUrl: s.latest!.streamUrl,
                network: Network.castopod,
                artwork: s.artwork,
                duration: s.latest!.duration,
                url: s.link,
                host: s.host,
                publishedAt: s.lastEpisodeAt,
                uploaderHandle: s.handle,
                episode: true,
              ),
          ];
          final subscribed = [
            for (final f in follows)
              ?all
                  .where(
                    (s) =>
                        s.handle == f.name ||
                        s.feedUrl == f.name ||
                        s.feedUrl == f.instance,
                  )
                  .firstOrNull,
          ];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: AudioIntro(
                  icon: Icons.podcasts_rounded,
                  title: 'Podcasts do fediverso',
                  text:
                      '${compact(all.length)} podcasts do Castopod. Ouça sem conta. Cada podcast também é uma conta do fediverso: com a sua, você segue e comenta os episódios.',
                  network: Network.castopod,
                  actions: [
                    AudioIntroButton(
                      label: 'Conta para comentar',
                      icon: Icons.auto_awesome_rounded,
                      primary: true,
                      onTap: () =>
                          openFediverse(context, start: FediStart.create),
                    ),
                    AudioIntroButton(
                      label: 'Publicar meu podcast',
                      icon: Icons.mic_rounded,
                      onTap: () =>
                          openFediverse(context, start: FediStart.podcaster),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _query = v.trim();
                      _shown = 36;
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Buscar podcasts',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _ChipRow(
                  children: [
                    ChoiceChip(
                      selected: _lang == null,
                      label: const Text('Todos os idiomas'),
                      onSelected: (_) => setState(() => _lang = null),
                    ),
                    for (final l in langs)
                      ChoiceChip(
                        selected: _lang == l,
                        label: Text(languageNames[l] ?? l.toUpperCase()),
                        onSelected: (_) => setState(() => _lang = l),
                      ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _ChipRow(
                  children: [
                    ChoiceChip(
                      selected: _category == null,
                      label: const Text('Todos os temas'),
                      onSelected: (_) => setState(() => _category = null),
                    ),
                    for (final c in cats)
                      ChoiceChip(
                        selected: _category == c,
                        label: Text(categoryNames[c] ?? c),
                        onSelected: (_) => setState(() => _category = c),
                      ),
                  ],
                ),
              ),
              if (subscribed.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: SectionHeader('Suas inscrições', emoji: '🔔'),
                ),
                SliverToBoxAdapter(child: _ShowCarousel(shows: subscribed)),
              ],
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: MessageView(
                    emoji: '🎙️',
                    title: 'Nenhum podcast com esses filtros',
                  ),
                )
              else ...[
                const SliverToBoxAdapter(
                  child: SectionHeader(
                    'Em alta',
                    emoji: '🔥',
                    subtitle: 'Os mais ouvidos segundo o OP3',
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ShowCarousel(shows: popular.take(16).toList()),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Episódios novos',
                    emoji: '🆕',
                    action: 'Tocar em sequência',
                    onAction: () =>
                        AudioPlayerService.instance.play(freshEpisodes),
                  ),
                ),
                SliverList.builder(
                  itemCount: freshEpisodes.length,
                  itemBuilder: (context, i) =>
                      TrackRow(items: freshEpisodes, index: i),
                ),
                SliverToBoxAdapter(
                  child: SectionHeader(
                    'Todos os podcasts',
                    emoji: '🎙️',
                    subtitle: '${filtered.length} resultados',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 190,
                          mainAxisExtent: 250,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                    itemCount: popular.length.clamp(0, _shown),
                    itemBuilder: (context, i) =>
                        _ShowTile(show: popular[i], width: null),
                  ),
                ),
                if (popular.length > _shown)
                  SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: OutlinedButton(
                          onPressed: () => setState(() => _shown += 36),
                          child: const Text('Mostrar mais'),
                        ),
                      ),
                    ),
                  ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          );
        },
      ),
    );
  }

  /// Valores mais frequentes, do mais comum ao menos comum.
  static List<String> _top(Iterable<String> values, int n) {
    final count = <String, int>{};
    for (final v in values) {
      if (v.isEmpty) continue;
      count[v] = (count[v] ?? 0) + 1;
    }
    final sorted = count.keys.toList()
      ..sort((a, b) => count[b]!.compareTo(count[a]!));
    return sorted.take(n).toList();
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      children: [
        for (final c in children)
          Padding(padding: const EdgeInsets.only(right: 8), child: c),
      ],
    ),
  );
}

class _ShowCarousel extends StatelessWidget {
  const _ShowCarousel({required this.shows});
  final List<Show> shows;

  @override
  Widget build(BuildContext context) => Carousel(
    height: 250,
    itemCount: shows.length,
    itemBuilder: (context, i) => _ShowTile(show: shows[i]),
  );
}

class _ShowTile extends StatelessWidget {
  const _ShowTile({required this.show, this.width = 170});
  final Show show;
  final double? width;

  @override
  Widget build(BuildContext context) => CoverTile(
    width: width,
    image: show.artwork,
    title: show.title,
    subtitle: [
      if (show.author.isNotEmpty) show.author,
      if (show.lastEpisodeAt != null) timeAgo(show.lastEpisodeAt!),
    ].join(' · '),
    onTap: () => openShow(context, show),
  );
}

void openShow(BuildContext context, Show show) =>
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => PodcastScreen(show: show)));

/// Página de um podcast: capa, inscrição e episódios do feed.
class PodcastScreen extends ConsumerWidget {
  const PodcastScreen({super.key, required this.show});
  final Show show;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jc = context.jc;
    final feed = ref.watch(podcastFeedProvider(show));
    final full = feed.value?.$1 ?? show;
    final episodes = feed.value?.$2 ?? const <AudioItem>[];
    final subscribed = ref.watch(
      settingsProvider.select((s) => s.isFollowing(show.asCommunity().key)),
    );
    final wide = MediaQuery.sizeOf(context).width > 640;

    final info = Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('PODCAST', style: context.tt.labelSmall),
        const SizedBox(height: 6),
        Text(
          full.title,
          style: context.tt.displaySmall,
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (full.author.isNotEmpty) full.author,
            if (full.episodes != null) '${full.episodes} episódios',
            if (full.language != null)
              languageNames[full.language] ?? full.language!,
          ].join(' · '),
          style: context.tt.bodyLarge?.copyWith(color: jc.muted),
          textAlign: wide ? TextAlign.start : TextAlign.center,
        ),
        if (full.handle != null) ...[
          const SizedBox(height: 6),
          Text('@${full.handle}', style: context.tt.labelMedium),
        ],
        const SizedBox(height: 16),
        Wrap(
          alignment: wide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              // Sem o feed, toca o último episódio que veio no índice.
              onPressed: episodes.isNotEmpty
                  ? () => AudioPlayerService.instance.play(episodes)
                  : show.latest == null
                  ? null
                  : () => AudioPlayerService.instance.play([show.latest!]),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Ouvir o mais recente'),
            ),
            FollowButton(
              following: subscribed,
              onTap: () => subscribeShow(context, ref, full),
            ),
            if (full.link != null)
              OutlinedButton.icon(
                onPressed: () => openUrl(full.link!),
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Comentar no Castopod'),
              ),
          ],
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 140),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 220,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: NetImage(
                                full.artwork,
                                radius: 22,
                                cacheWidth: 600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          Flexible(child: info),
                        ],
                      )
                    : Column(
                        children: [
                          SizedBox(
                            width: 200,
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: NetImage(
                                full.artwork,
                                radius: 22,
                                cacheWidth: 600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          info,
                        ],
                      ),
              ),
              if (full.description?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: Text(
                    full.description!,
                    style: context.tt.bodyMedium?.copyWith(color: jc.muted),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (full.categories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in full.categories)
                        Chip(label: Text(categoryNames[c] ?? c)),
                    ],
                  ),
                ),
              const Divider(),
              feed.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Não consegui ler o feed deste podcast agora.',
                    style: context.tt.bodySmall,
                  ),
                ),
                data: (_) => Column(
                  children: [
                    for (var i = 0; i < episodes.length; i++)
                      TrackRow(items: episodes, index: i),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
