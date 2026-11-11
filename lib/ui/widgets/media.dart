import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import 'basics.dart';

/// Grade de mídia de um post: 1, 2, 3 ou 4+ itens com cantos arredondados.
class MediaGrid extends ConsumerStatefulWidget {
  const MediaGrid({super.key, required this.post, this.maxHeight = 520});
  final Post post;
  final double maxHeight;

  @override
  ConsumerState<MediaGrid> createState() => _MediaGridState();
}

class _MediaGridState extends ConsumerState<MediaGrid> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final media = widget.post.media;
    if (media.isEmpty) return const SizedBox.shrink();
    final hide =
        widget.post.sensitive &&
        !_revealed &&
        !ref.watch(settingsProvider).showSensitive;

    Widget tile(int i, {double? aspect}) {
      final m = media[i];
      return GestureDetector(
        onTap: () => m.isVideo
            ? openClips(context, [widget.post], 0)
            : openMedia(context, media, i),
        child: Stack(
          fit: StackFit.expand,
          children: [
            NetImage(m.thumb, blurhash: m.blurhash, cacheWidth: 900),
            if (m.isVideo) const _PlayBadge(),
            if (i == 3 && media.length > 4)
              ColoredBox(
                color: Colors.black45,
                child: Center(
                  child: Text(
                    '+${media.length - 4}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    const gap = 3.0;
    Widget grid;
    switch (media.length) {
      case 1:
        final a = (media.first.aspect ?? 1.5).clamp(.72, 2.0);
        grid = AspectRatio(aspectRatio: a, child: tile(0));
      case 2:
        grid = AspectRatio(
          aspectRatio: 1.7,
          child: Row(
            children: [
              Expanded(child: tile(0)),
              const SizedBox(width: gap),
              Expanded(child: tile(1)),
            ],
          ),
        );
      case 3:
        grid = AspectRatio(
          aspectRatio: 1.5,
          child: Row(
            children: [
              Expanded(flex: 3, child: tile(0)),
              const SizedBox(width: gap),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Expanded(child: tile(1)),
                    const SizedBox(height: gap),
                    Expanded(child: tile(2)),
                  ],
                ),
              ),
            ],
          ),
        );
      default:
        grid = AspectRatio(
          aspectRatio: 1.4,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: tile(0)),
                    const SizedBox(width: gap),
                    Expanded(child: tile(1)),
                  ],
                ),
              ),
              const SizedBox(height: gap),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: tile(2)),
                    const SizedBox(width: gap),
                    Expanded(child: tile(3)),
                  ],
                ),
              ),
            ],
          ),
        );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: ClipRRect(
        borderRadius: context.jc.r(18),
        child: Stack(
          children: [
            grid,
            if (hide)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _revealed = true),
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: .35),
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_off_rounded,
                                color: Colors.white,
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Conteúdo sensível · toque para ver',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: .45),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 34,
      ),
    ),
  );
}

class LinkCardView extends StatelessWidget {
  const LinkCardView(this.card, {super.key, this.compact = false});
  final LinkCard card;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final provider = card.provider?.isNotEmpty ?? false
        ? card.provider!
        : hostOf(card.url);
    final info = Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            provider.toUpperCase(),
            style: context.tt.labelSmall,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            card.title,
            style: context.tt.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!compact && (card.description?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 4),
            Text(
              card.description!,
              style: context.tt.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
    return Material(
      color: jc.card,
      shape: RoundedRectangleBorder(
        borderRadius: context.jc.r(18),
        side: BorderSide(color: jc.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openUrl(card.url),
        child: compact || card.image == null
            ? Row(
                children: [
                  if (card.image != null)
                    SizedBox(
                      width: 92,
                      height: 92,
                      child: NetImage(card.image, blurhash: card.blurhash),
                    ),
                  Expanded(child: info),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.91,
                    child: NetImage(
                      card.image,
                      blurhash: card.blurhash,
                      cacheWidth: 900,
                    ),
                  ),
                  info,
                ],
              ),
      ),
    );
  }
}

/// Visualizador em tela cheia com zoom e paginação.
class MediaViewer extends StatefulWidget {
  const MediaViewer({super.key, required this.media, this.initial = 0});
  final List<Media> media;
  final int initial;

  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.media[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.media.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: NetImage(
                  widget.media[i].url,
                  fit: BoxFit.contain,
                  blurhash: widget.media[i].blurhash,
                  // Não decodificar fotos de 40+ MP na resolução original.
                  cacheWidth:
                      (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context) *
                              1.5)
                          .round()
                          .clamp(1024, 4096),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white12,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (widget.media.length > 1)
                    Text(
                      '${_index + 1} / ${widget.media.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (m.alt?.isNotEmpty ?? false)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: context.jc.r(16),
                  ),
                  child: Text(
                    m.alt!,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grade "masonry" (estilo Pinterest/Instagram explorar) que respeita a
/// proporção de cada foto.
class MasonrySliver extends StatelessWidget {
  const MasonrySliver({
    super.key,
    required this.items,
    required this.columns,
    this.gap = 6,
  });
  final List<Post> items;
  final int columns;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cols = List.generate(columns, (_) => <(Post, int)>[]);
    final heights = List.filled(columns, 0.0);
    for (var i = 0; i < items.length; i++) {
      final img = items[i].media.firstWhere(
        (m) => m.type == MediaType.image,
        orElse: () => items[i].media.first,
      );
      final aspect = (img.aspect ?? 1).clamp(.55, 1.8);
      var shortest = 0;
      for (var c = 1; c < columns; c++) {
        if (heights[c] < heights[shortest]) shortest = c;
      }
      cols[shortest].add((items[i], i));
      heights[shortest] += 1 / aspect;
    }
    // Cada coluna é uma SliverList: só os tiles perto da viewport são
    // construídos, mesmo depois de muitas páginas carregadas.
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: gap),
      sliver: SliverCrossAxisGroup(
        slivers: [
          for (var c = 0; c < columns; c++)
            SliverCrossAxisExpanded(
              flex: 1,
              sliver: SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: gap / 2),
                sliver: SliverList.builder(
                  itemCount: cols[c].length,
                  itemBuilder: (context, i) =>
                      _PhotoTile(post: cols[c][i].$1, gap: gap),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatefulWidget {
  const _PhotoTile({required this.post, required this.gap});
  final Post post;
  final double gap;

  @override
  State<_PhotoTile> createState() => _PhotoTileState();
}

class _PhotoTileState extends State<_PhotoTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final img = p.media.firstWhere(
      (m) => m.type == MediaType.image,
      orElse: () => p.media.first,
    );
    final aspect = (img.aspect ?? 1).clamp(.55, 1.8);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.gap),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => openPost(context, p),
          child: ClipRRect(
            borderRadius: context.jc.r(16),
            child: AspectRatio(
              aspectRatio: aspect.toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedScale(
                    scale: _hover ? 1.04 : 1,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOut,
                    child: NetImage(
                      img.thumb,
                      blurhash: img.blurhash,
                      cacheWidth: 600,
                    ),
                  ),
                  if (p.media.length > 1)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(
                        Icons.collections_rounded,
                        color: Colors.white,
                        size: 18,
                        shadows: [Shadow(blurRadius: 6)],
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedOpacity(
                      opacity: _hover ? 1 : .0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                        child: Row(
                          children: [
                            Avatar(
                              url: p.author.avatar,
                              size: 22,
                              label: p.author.displayName,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p.author.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.favorite_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              compact(p.likes),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
