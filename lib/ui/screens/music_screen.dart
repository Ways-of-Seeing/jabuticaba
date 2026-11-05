import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../models/audio.dart';
import '../../models/models.dart';
import '../../services/funkwhale.dart';
import '../../state/accounts.dart';
import '../../state/audio.dart';
import '../../state/player.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/audio.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';
import 'fediverse_screen.dart';

/// Aba "Música": Funkwhale, a biblioteca de música federada.
class MusicScreen extends ConsumerStatefulWidget {
  const MusicScreen({super.key});

  @override
  ConsumerState<MusicScreen> createState() => _MusicScreenState();
}

class _MusicScreenState extends ConsumerState<MusicScreen> {
  String? _pod;
  String _query = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final hasAccount = ref
        .watch(accountsProvider)
        .any((a) => a.kind == AccountKind.funkwhale && !a.pending);
    final albums = ref.watch(albumsProvider(_pod));
    final tracks = ref.watch(tracksProvider((_pod, _query)));
    final favorites = hasAccount ? ref.watch(musicFavoritesProvider) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(jc.headline('Música')),
        toolbarHeight: 64,
        titleTextStyle: context.tt.headlineLarge?.copyWith(
          color: jc.onTitleBar,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(albumsProvider);
          ref.invalidate(tracksProvider);
          ref.invalidate(musicFavoritesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: AudioIntro(
                icon: Icons.album_rounded,
                title: 'Música livre e federada',
                text: 'Artistas independentes publicando no Funkwhale. Ouça sem conta; com uma conta, monte seus favoritos e siga quem você curte.',
                network: Network.funkwhale,
                actions: [
                  if (!hasAccount)
                    AudioIntroButton(
                      label: 'Criar conta de música',
                      icon: Icons.auto_awesome_rounded,
                      primary: true,
                      onTap: () =>
                          openFediverse(context, start: FediStart.music),
                    ),
                  if (!hasAccount)
                    AudioIntroButton(
                      label: 'Já tenho Funkwhale',
                      icon: Icons.link_rounded,
                      onTap: () =>
                          openFediverse(context, start: FediStart.musicConnect),
                    ),
                  AudioIntroButton(
                    label: 'Publicar minhas músicas',
                    icon: Icons.upload_rounded,
                    onTap: () => openUrl(
                      'https://${_pod ?? FunkwhaleApi.signupPods.first}/content/libraries',
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) => setState(() => _query = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar faixas e artistas',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _search.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _pod == null,
                        label: const Text('Todos os servidores'),
                        onSelected: (_) => setState(() => _pod = null),
                      ),
                    ),
                    for (final p in FunkwhaleApi.pods)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _pod == p,
                          label: Text(p),
                          onSelected: (_) => setState(() => _pod = p),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (favorites?.value case final favs? when favs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader(
                  'Seus favoritos',
                  emoji: '♥',
                  subtitle: '${favs.length} faixas',
                  action: 'Tocar',
                  onAction: () => AudioPlayerService.instance.play(favs),
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    for (var i = 0; i < min(5, favs.length); i++)
                      TrackRow(items: favs, index: i),
                  ],
                ),
              ),
            ],
            if (_query.isEmpty) ...[
              const SliverToBoxAdapter(
                child: SectionHeader('Álbuns recentes', emoji: '💿'),
              ),
              SliverToBoxAdapter(
                child: albums.when(
                  loading: () =>
                      const CarouselSkeleton(height: 230, width: 170),
                  error: (e, _) =>
                      _Problem(onRetry: () => ref.invalidate(albumsProvider)),
                  data: (list) => list.isEmpty
                      ? const SizedBox(height: 40)
                      : Carousel(
                          height: 236,
                          itemCount: list.length,
                          itemBuilder: (context, i) => CoverTile(
                            image: list[i].artwork,
                            title: list[i].title,
                            subtitle: list[i].artist,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AlbumScreen(album: list[i]),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: SectionHeader(
                _query.isEmpty ? 'Faixas novas' : 'Resultados para "$_query"',
                emoji: '🎧',
                subtitle:
                    _pod ??
                    'De ${FunkwhaleApi.pods.length} servidores Funkwhale',
                action: 'Tocar tudo',
                onAction: () {
                  final list = tracks.value;
                  if (list != null && list.isNotEmpty) {
                    AudioPlayerService.instance.play(list);
                  }
                },
              ),
            ),
            ...tracks.when(
              loading: () => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(
                  child: _Problem(
                    onRetry: () => ref.invalidate(tracksProvider),
                  ),
                ),
              ],
              data: (list) => [
                if (list.isEmpty)
                  const SliverToBoxAdapter(
                    child: MessageView(emoji: '🔇', title: 'Nada encontrado'),
                  )
                else
                  SliverList.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) =>
                        TrackRow(items: list, index: i),
                  ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 140)),
          ],
        ),
      ),
    );
  }
}

class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key, required this.album});
  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jc = context.jc;
    final tracks = ref.watch(albumTracksProvider(album));
    final wide = MediaQuery.sizeOf(context).width > 640;
    final header = [
      SizedBox(
        width: wide ? 220 : 200,
        child: AspectRatio(
          aspectRatio: 1,
          child: Artwork(album.artwork, radius: 22, cacheWidth: 600),
        ),
      ),
      SizedBox(width: wide ? 28 : 0, height: wide ? 0 : 18),
      Flexible(
        child: Column(
          crossAxisAlignment: wide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ÁLBUM', style: context.tt.labelSmall),
            const SizedBox(height: 6),
            Text(
              album.title,
              style: context.tt.displaySmall,
              textAlign: wide ? TextAlign.start : TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              [
                album.artist,
                if (album.year != null) '${album.year}',
                if (album.tracks != null) '${album.tracks} faixas',
              ].join(' · '),
              style: context.tt.bodyLarge?.copyWith(color: jc.muted),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                NetworkPill(Network.funkwhale, dense: true),
                const SizedBox(width: 8),
                Text(album.host, style: context.tt.labelMedium),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: tracks.value == null || tracks.value!.isEmpty
                      ? null
                      : () => AudioPlayerService.instance.play(tracks.value!),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Tocar'),
                ),
                OutlinedButton.icon(
                  onPressed: tracks.value == null || tracks.value!.isEmpty
                      ? null
                      : () => AudioPlayerService.instance.play(
                          [...tracks.value!]..shuffle(),
                        ),
                  icon: const Icon(Icons.shuffle_rounded),
                  label: const Text('Aleatório'),
                ),
                OutlinedButton.icon(
                  onPressed: () => openUrl(
                    'https://${album.host}/library/albums/${album.id}',
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Abrir no servidor'),
                ),
              ],
            ),
          ],
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 140),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: header,
                      )
                    : Column(children: header),
              ),
              tracks.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _Problem(
                  onRetry: () => ref.invalidate(albumTracksProvider(album)),
                ),
                data: (list) => Column(
                  children: [
                    for (var i = 0; i < list.length; i++)
                      TrackRow(items: list, index: i, showArt: false),
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

class _Problem extends StatelessWidget {
  const _Problem({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Row(
      children: [
        Expanded(
          child: Text(
            'Este servidor não respondeu agora.',
            style: context.tt.bodySmall,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
      ],
    ),
  );
}
