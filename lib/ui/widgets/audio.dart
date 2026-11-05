import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/audio.dart';
import '../../models/models.dart';
import '../../state/player.dart';
import '../nav.dart';
import '../theme.dart';
import 'audio_actions.dart';
import 'basics.dart';

String fmtDuration(Duration d) => duration(d.inSeconds);

/// Barra fixa com o que está tocando. Some quando não há nada na fila.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final p = AudioPlayerService.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final item = p.current;
        if (item == null) return const SizedBox.shrink();
        final jc = context.jc;
        final total = p.duration.inMilliseconds;
        final progress = total == 0
            ? 0.0
            : (p.position.inMilliseconds / total).clamp(0.0, 1.0);
        return Material(
          color: dark ? const Color(0xFF15091A) : jc.cardHigh,
          child: InkWell(
            onTap: () => showFullPlayer(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  color: jc.brand,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                  child: Row(
                    children: [
                      Artwork(
                        item.artwork,
                        width: 44,
                        height: 44,
                        radius: 10,
                        cacheWidth: 140,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.titleSmall?.copyWith(
                                color: dark ? Colors.white : null,
                              ),
                            ),
                            Text(
                              p.error != null
                                  ? 'Não foi possível tocar'
                                  : item.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.tt.bodySmall?.copyWith(
                                color: dark ? Colors.white60 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (p.hasPrevious)
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: p.previous,
                          icon: Icon(
                            Icons.skip_previous_rounded,
                            color: dark ? Colors.white : null,
                          ),
                        ),
                      p.loading
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              ),
                            )
                          : IconButton.filled(
                              tooltip: p.playing ? 'Pausar' : 'Tocar',
                              style: IconButton.styleFrom(
                                backgroundColor: jc.brand,
                                foregroundColor: jc.onAccent,
                              ),
                              onPressed: p.toggle,
                              icon: Icon(
                                p.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                      if (p.hasNext)
                        IconButton(
                          tooltip: 'Próxima',
                          onPressed: p.next,
                          icon: Icon(
                            Icons.skip_next_rounded,
                            color: dark ? Colors.white : null,
                          ),
                        ),
                      IconButton(
                        tooltip: 'Fechar player',
                        onPressed: p.stop,
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: dark ? Colors.white60 : jc.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<void> showFullPlayer(BuildContext context) => showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 560),
  builder: (_) => const _FullPlayer(),
);

class _FullPlayer extends ConsumerWidget {
  const _FullPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AudioPlayerService.instance;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final item = p.current;
        if (item == null) return const SizedBox(height: 120);
        final jc = context.jc;
        final total = p.duration;
        final pos = p.position > total && total > Duration.zero
            ? total
            : p.position;
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: jc.r(26),
                          boxShadow: jc.retro
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: .35),
                                    blurRadius: 30,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                        ),
                        child: Artwork(
                          item.artwork,
                          radius: 26,
                          cacheWidth: 700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  item.title,
                  style: context.tt.headlineSmall,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  [item.artist, if (item.album != null) item.album].join(' · '),
                  style: context.tt.bodyMedium?.copyWith(color: jc.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Center(child: NetworkPill(item.network, dense: true)),
                const SizedBox(height: 14),
                Slider(
                  value: pos.inMilliseconds.toDouble().clamp(
                    0,
                    (total.inMilliseconds == 0 ? 1 : total.inMilliseconds)
                        .toDouble(),
                  ),
                  max: (total.inMilliseconds == 0 ? 1 : total.inMilliseconds)
                      .toDouble(),
                  onChanged: total == Duration.zero
                      ? null
                      : (v) => p.seek(Duration(milliseconds: v.round())),
                ),
                Row(
                  children: [
                    Text(fmtDuration(pos), style: context.tt.labelMedium),
                    const Spacer(),
                    Text(
                      total == Duration.zero ? '--:--' : fmtDuration(total),
                      style: context.tt.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (item.episode)
                      IconButton(
                        tooltip: 'Voltar 15 s',
                        iconSize: 30,
                        onPressed: () => p.skip(const Duration(seconds: -15)),
                        icon: const Icon(Icons.replay_10_rounded),
                      )
                    else
                      IconButton(
                        tooltip: 'Anterior',
                        iconSize: 34,
                        onPressed: p.previous,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                    const SizedBox(width: 14),
                    SizedBox.square(
                      dimension: 72,
                      child: p.loading
                          ? const Center(child: CircularProgressIndicator())
                          : IconButton.filled(
                              iconSize: 40,
                              style: IconButton.styleFrom(
                                backgroundColor: jc.brand,
                                foregroundColor: jc.onAccent,
                                shape: jc.square
                                    ? const RoundedRectangleBorder()
                                    : null,
                              ),
                              onPressed: p.toggle,
                              icon: Icon(
                                p.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    if (item.episode)
                      IconButton(
                        tooltip: 'Avançar 30 s',
                        iconSize: 30,
                        onPressed: () => p.skip(const Duration(seconds: 30)),
                        icon: const Icon(Icons.forward_30_rounded),
                      )
                    else
                      IconButton(
                        tooltip: 'Próxima',
                        iconSize: 34,
                        onPressed: p.hasNext ? p.next : null,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                  ],
                ),
                if (item.episode) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: SegmentedButton<double>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 1, label: Text('1×')),
                        ButtonSegment(value: 1.25, label: Text('1,25×')),
                        ButtonSegment(value: 1.5, label: Text('1,5×')),
                        ButtonSegment(value: 2, label: Text('2×')),
                      ],
                      selected: {p.speed},
                      onSelectionChanged: (s) => p.setSpeed(s.first),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (!item.episode)
                      OutlinedButton.icon(
                        onPressed: () => favoriteTrack(context, ref, item),
                        icon: const Icon(
                          Icons.favorite_border_rounded,
                          size: 18,
                        ),
                        label: const Text('Favoritar'),
                      ),
                    if (item.uploaderHandle != null)
                      OutlinedButton.icon(
                        onPressed: () => followUploader(context, ref, item),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 18,
                        ),
                        label: Text(
                          item.episode
                              ? 'Seguir o podcast'
                              : 'Seguir quem publicou',
                        ),
                      ),
                    if (item.url != null)
                      OutlinedButton.icon(
                        onPressed: () => openUrl(item.url!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(
                          item.episode
                              ? 'Comentar no site'
                              : 'Abrir no servidor',
                        ),
                      ),
                  ],
                ),
                if (item.description?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 18),
                  Text(
                    item.description!,
                    style: context.tt.bodyMedium?.copyWith(color: jc.muted),
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (p.queue.length > 1) ...[
                  const SizedBox(height: 20),
                  Text('A seguir', style: context.tt.titleMedium),
                  for (
                    var i = p.index + 1;
                    i < p.queue.length && i < p.index + 6;
                    i++
                  )
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Artwork(
                        p.queue[i].artwork,
                        width: 40,
                        height: 40,
                        radius: 8,
                        cacheWidth: 120,
                      ),
                      title: Text(
                        p.queue[i].title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.queue[i].artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => p.play(p.queue, i),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Linha de faixa ou episódio, com indicação do que está tocando.
class TrackRow extends ConsumerWidget {
  const TrackRow({
    super.key,
    required this.items,
    required this.index,
    this.showArt = true,
  });
  final List<AudioItem> items;
  final int index;
  final bool showArt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = items[index];
    final p = AudioPlayerService.instance;
    final jc = context.jc;
    return ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final isCurrent = p.current?.key == item.key;
        final meta = [
          if (item.episode && item.publishedAt != null)
            timeAgo(item.publishedAt!)
          else
            item.artist,
          if (item.duration != null) fmtDuration(item.duration!),
        ].join(' · ');
        return Material(
          color: isCurrent
              ? jc.brand.withValues(alpha: .1)
              : Colors.transparent,
          child: InkWell(
            onTap: () => p.play(items, index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  if (showArt)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Artwork(
                          item.artwork,
                          width: 52,
                          height: 52,
                          radius: 10,
                          cacheWidth: 160,
                        ),
                        if (isCurrent)
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: jc.r(10),
                            ),
                            child: Icon(
                              p.playing
                                  ? Icons.graphic_eq_rounded
                                  : Icons.pause_rounded,
                              color: Colors.white,
                            ),
                          ),
                      ],
                    )
                  else
                    SizedBox(
                      width: 32,
                      child: isCurrent
                          ? Icon(Icons.graphic_eq_rounded, color: jc.brand)
                          : Text(
                              '${index + 1}',
                              style: context.tt.labelLarge?.copyWith(
                                color: jc.muted,
                              ),
                              textAlign: TextAlign.center,
                            ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall?.copyWith(
                            color: isCurrent ? jc.brand : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (!item.episode)
                    IconButton(
                      tooltip: 'Favoritar',
                      onPressed: () => favoriteTrack(context, ref, item),
                      icon: Icon(
                        Icons.favorite_border_rounded,
                        size: 20,
                        color: jc.muted,
                      ),
                    ),
                  IconButton(
                    tooltip: isCurrent && p.playing ? 'Pausar' : 'Tocar',
                    onPressed: () => p.play(items, index),
                    icon: Icon(
                      isCurrent && p.playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                      size: 34,
                      color: jc.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Capa quadrada com título (álbum, podcast).
class CoverTile extends StatelessWidget {
  const CoverTile({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.width = 170,
    this.badge,
  });
  final String? image;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final double? width;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Artwork(image, radius: 18, cacheWidth: 500),
                    if (badge != null)
                      Positioned(top: 8, left: 8, child: badge!),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.tt.titleSmall,
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.tt.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cabeçalho reaproveitado por Música e Podcasts.
class AudioIntro extends StatelessWidget {
  const AudioIntro({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    required this.network,
    required this.actions,
  });
  final IconData icon;
  final String title;
  final String text;
  final Network network;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: jc.accentPanel(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: jc.onAccent, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: context.tt.headlineSmall?.copyWith(
                      color: jc.onAccent,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .2),
                    borderRadius: jc.r(30),
                  ),
                  child: Text(
                    network.label,
                    style: TextStyle(
                      color: jc.onAccent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: context.tt.bodyMedium?.copyWith(
                color: jc.onAccent.withValues(alpha: .88),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        ),
      ),
    );
  }
}

class AudioIntroButton extends StatelessWidget {
  const AudioIntroButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return primary
        ? FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: jc.onAccent,
              foregroundColor: jc.accent.colors.first,
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          )
        : OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: jc.onAccent,
              side: BorderSide(color: jc.onAccent.withValues(alpha: .6)),
            ),
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
          );
  }
}

/// Capa de álbum/podcast; sem imagem, mostra um disco no degradê do tema.
class Artwork extends StatelessWidget {
  const Artwork(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.radius = 0,
    this.cacheWidth,
  });
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return NetImage(
        url,
        width: width,
        height: height,
        radius: radius,
        cacheWidth: cacheWidth,
      );
    }
    final jc = context.jc;
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: jc.accent,
          borderRadius: jc.r(radius),
        ),
        child: LayoutBuilder(
          builder: (context, c) => Center(
            child: Icon(
              Icons.album_rounded,
              color: jc.onAccent.withValues(alpha: .7),
              size: c.biggest.shortestSide * .45,
            ),
          ),
        ),
      ),
    );
  }
}
