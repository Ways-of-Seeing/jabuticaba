import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/directory.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import 'basics.dart';
import 'rich_content.dart';

/// Carrossel horizontal com altura fixa.
class Carousel extends StatelessWidget {
  const Carousel({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 12,
  });
  final double height;
  final int itemCount;
  final double spacing;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: itemBuilder,
      ),
    );
  }
}

/// Carrossel de esqueletos enquanto carrega.
class CarouselSkeleton extends StatelessWidget {
  const CarouselSkeleton({
    super.key,
    required this.height,
    required this.width,
  });
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) => Carousel(
    height: height,
    itemCount: 6,
    itemBuilder: (_, _) =>
        Skeleton(width: width, height: height, radius: context.jc.radius),
  );
}

/// Prévia vertical de um clipe (capa 9:16 com autor).
class ClipThumb extends StatelessWidget {
  const ClipThumb({
    super.key,
    required this.post,
    required this.onTap,
    this.width = 150,
  });
  final Post post;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final m = post.media.firstWhere((m) => m.isVideo);
    return _Hover(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: ClipRRect(
          borderRadius: context.jc.r(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              NetImage(m.thumb, blurhash: m.blurhash, cacheWidth: 400),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [.5, 1],
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: NetworkPill(post.network, dense: true, onMedia: true),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (post.title?.isNotEmpty ?? false)
                          ? post.title!
                          : (post.text.isNotEmpty
                                ? post.text
                                : htmlToText(post.html)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        Text(
                          compact(post.views ?? post.likes),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
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

/// Cartão de vídeo horizontal (PeerTube, estilo YouTube).
class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.post, this.width = 280});
  final Post post;
  final double width;

  @override
  Widget build(BuildContext context) {
    final m = post.media.first;
    final secs = int.tryParse(m.alt ?? '');
    return _Hover(
      onTap: () => openClips(context, [post], 0),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: context.jc.r(18),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetImage(m.thumb, cacheWidth: 640),
                    if (secs != null && secs > 0)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: context.jc.r(8),
                          ),
                          child: Text(
                            duration(secs),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Avatar(
                  url: post.author.avatar,
                  size: 32,
                  label: post.author.displayName,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title ?? '',
                        style: context.tt.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${post.author.displayName} · ${compact(post.views)} visualizações',
                        style: context.tt.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão compacto de post em texto (carrossel "Conversas em alta").
class TalkCard extends StatelessWidget {
  const TalkCard({super.key, required this.post, this.width = 300});
  final Post post;
  final double width;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final thumb = post.media.isNotEmpty
        ? post.media.first.thumb
        : post.card?.image;
    return _Hover(
      onTap: () => openPost(context, post),
      child: Container(
        width: width,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: jc.card,
          borderRadius: context.jc.r(22),
          border: Border.all(color: jc.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Avatar(
                  url: post.author.avatar,
                  size: 34,
                  network: post.network,
                  label: post.author.displayName,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author.displayName,
                        style: context.tt.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        timeAgo(post.createdAt),
                        style: context.tt.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichContent(
                      html: post.html,
                      text: post.text,
                      network: post.network,
                      maxLines: thumb != null ? 5 : 6,
                      style: context.tt.bodyMedium,
                    ),
                  ),
                  if (thumb != null) ...[
                    const SizedBox(width: 10),
                    NetImage(
                      thumb,
                      width: 72,
                      height: 72,
                      radius: 12,
                      cacheWidth: 220,
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 15, color: jc.muted),
                const SizedBox(width: 4),
                Text(compact(post.likes), style: context.tt.labelMedium),
                const SizedBox(width: 14),
                Icon(Icons.chat_bubble_rounded, size: 14, color: jc.muted),
                const SizedBox(width: 4),
                Text(compact(post.replies), style: context.tt.labelMedium),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartão de comunidade/servidor/feed com capa e botão seguir.
class CommunityCard extends ConsumerWidget {
  const CommunityCard({super.key, required this.community, this.width = 260});
  final Community community;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = community;
    final jc = context.jc;
    final following = ref.watch(
      settingsProvider.select((s) => s.isFollowing(c.key)),
    );
    final hasBanner = c.banner?.isNotEmpty ?? false;
    final description = htmlToText(c.description);
    return _Hover(
      onTap: () => openCommunity(context, c),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: jc.card,
          borderRadius: context.jc.r(22),
          border: Border.all(color: jc.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 92,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  hasBanner
                      ? NetImage(
                          c.banner,
                          blurhash: c.blurhash,
                          cacheWidth: 600,
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.jc
                                    .network(c.network)
                                    .withValues(alpha: .85),
                                context.jc.brand.withValues(alpha: .9),
                              ],
                            ),
                          ),
                        ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: NetworkPill(c.network, dense: true, onMedia: true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (c.avatar != null) ...[
                          Avatar(
                            url: c.avatar,
                            size: 30,
                            square: true,
                            label: c.displayTitle,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            c.displayTitle,
                            style: context.tt.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        description.isEmpty ? _fallback(c) : description,
                        style: context.tt.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _stats(c),
                            style: context.tt.labelMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FollowButton(
                          following: following,
                          dense: true,
                          onTap: () => ref
                              .read(settingsProvider.notifier)
                              .toggleFollow(c),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fallback(Community c) => switch (c.kind) {
    CommunityKind.server => 'Um servidor do Mastodon',
    CommunityKind.group => 'Comunidade em ${c.name.split('@').last}',
    CommunityKind.feed => 'Feed de @${c.instance ?? 'bluesky'}',
    _ => c.name,
  };

  static String _stats(Community c) {
    final parts = <String>[
      if (c.activeMembers != null) '${compact(c.activeMembers)} ativos',
      if (c.activeMembers == null && c.members != null && c.members! > 0)
        '${compact(c.members)} ${c.kind == CommunityKind.feed ? 'curtidas' : 'membros'}',
      if (c.category != null)
        ServerDirectory.categoryLabels[c.category] ?? c.category!,
    ];
    return parts.join(' · ');
  }
}

/// Cartão de notícia (links em alta no Mastodon).
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.card, this.width = 280});
  final LinkCard card;
  final double width;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return _Hover(
      onTap: () => openUrl(card.url),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: jc.card,
          borderRadius: context.jc.r(22),
          border: Border.all(color: jc.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.9,
              child: NetImage(
                card.image,
                blurhash: card.blurhash,
                cacheWidth: 600,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (card.provider ?? hostOf(card.url)).toUpperCase(),
                    style: context.tt.labelSmall,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    card.title,
                    style: context.tt.titleSmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Leve elevação e cursor de clique ao passar o mouse (desktop).
class _Hover extends StatefulWidget {
  const _Hover({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _on = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _on = true),
      onExit: (_) => setState(() => _on = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedSlide(
          offset: _on ? const Offset(0, -.012) : Offset.zero,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _on ? 1.015 : 1,
            duration: const Duration(milliseconds: 180),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
