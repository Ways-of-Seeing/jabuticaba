import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';

import '../../models/models.dart';
import '../theme.dart';

/// Imagem de rede com placeholder (blurhash ou degradê) e fade-in suave.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.blurhash,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.width,
    this.height,
    this.cacheWidth,
  });

  final String? url;
  final String? blurhash;
  final BoxFit fit;
  final double radius;
  final double? width;
  final double? height;

  /// Largura de decodificação; economiza memória em grades de miniaturas.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final placeholder = _Placeholder(blurhash: blurhash);
    Widget child = url == null || url!.isEmpty
        ? placeholder
        : Image.network(
            url!,
            fit: fit,
            width: width,
            height: height,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            // Na web, cai para <img> quando o CDN não manda cabeçalhos CORS.
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            frameBuilder: (context, child, frame, sync) {
              if (sync) return child;
              return Stack(
                fit: StackFit.passthrough,
                children: [
                  Positioned.fill(child: placeholder),
                  AnimatedOpacity(
                    opacity: frame == null ? 0 : 1,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOut,
                    child: child,
                  ),
                ],
              );
            },
            errorBuilder: (_, _, _) => placeholder,
          );
    final filter = context.jc.imageFilter;
    if (filter != null) {
      child = ColorFiltered(colorFilter: filter, child: child);
    }
    if (radius > 0 && !context.jc.square) {
      child = ClipRRect(borderRadius: context.jc.r(radius), child: child);
    }
    return SizedBox(width: width, height: height, child: child);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.blurhash});
  final String? blurhash;

  @override
  Widget build(BuildContext context) {
    final hash = blurhash;
    if (hash != null && hash.length >= 6) {
      return BlurHash(
        hash: hash,
        imageFit: BoxFit.cover,
        duration: Duration.zero,
      );
    }
    final jc = context.jc;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [jc.cardHigh, jc.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    this.url,
    this.size = 42,
    this.network,
    this.square = false,
    this.label,
  });

  final String? url;
  final double size;
  final Network? network;
  final bool square;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final radius = jc.square ? 0.0 : (square ? size * .28 : size / 2);
    final initials = (label ?? '').trim().isEmpty
        ? '?'
        : label!.trim().characters.first.toUpperCase();
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox.square(
        dimension: size,
        child: url == null || url!.isEmpty
            ? DecoratedBox(
                decoration: BoxDecoration(gradient: jc.accent),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: jc.onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: size * .42,
                    ),
                  ),
                ),
              )
            : NetImage(url, cacheWidth: (size * 3).round()),
      ),
    );
    if (network == null) return img;
    final badge = size * .4;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          img,
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: jc.network(network!),
                shape: jc.square ? BoxShape.rectangle : BoxShape.circle,
                border: Border.all(color: context.jc.canvas, width: 2),
              ),
              child: Icon(
                Jabu.networkIcon(network!),
                size: badge * .55,
                color: jc.monoNetworks ? jc.canvas : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NetworkPill extends StatelessWidget {
  const NetworkPill(
    this.network, {
    super.key,
    this.dense = false,
    this.onMedia = false,
  });
  final Network network;
  final bool dense;

  /// Versão para sobrepor fotos e vídeos.
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final color = context.jc.network(network);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: onMedia
            ? Colors.black.withValues(alpha: .45)
            : color.withValues(alpha: .14),
        borderRadius: context.jc.r(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Jabu.networkIcon(network),
            size: dense ? 11 : 13,
            color: onMedia ? Colors.white : color,
          ),
          const SizedBox(width: 4),
          Text(
            network.label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              color: onMedia ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
    this.emoji,
  });
  final String title;
  final String? subtitle;
  final String? emoji;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 30, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  emoji == null ||
                          context.jc.square &&
                              context.jc.id != JabuThemeId.win95
                      ? context.jc.headline(title)
                      : '$emoji  ${context.jc.headline(title)}',
                  style: context.tt.headlineSmall,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: context.tt.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(action!),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Esqueleto pulsante enquanto o conteúdo carrega.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius});
  final double? width;
  final double? height;

  /// `null` usa o raio pequeno do tema.
  final double? radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            jc.card,
            jc.cardHigh,
            Curves.easeInOut.transform(_c.value),
          ),
          borderRadius: widget.radius == null ? jc.r(14) : jc.r(widget.radius!),
        ),
      ),
    );
  }
}

class MessageView extends StatelessWidget {
  const MessageView({
    super.key,
    required this.emoji,
    required this.title,
    this.message,
    this.action,
    this.onAction,
  });

  final String emoji;
  final String title;
  final String? message;
  final String? action;
  final VoidCallback? onAction;

  factory MessageView.error(Object error, VoidCallback retry) => MessageView(
    emoji: '🫐',
    title: 'Não deu pra carregar agora',
    message: 'Algum servidor do fediverso não respondeu. Tente de novo em instantes.',
    action: 'Tentar de novo',
    onAction: retry,
  );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 14),
              Text(
                title,
                style: context.tt.titleLarge,
                textAlign: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 8),
                Text(
                  message!,
                  style: context.tt.bodyMedium?.copyWith(
                    color: context.jc.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 20),
                FilledButton.tonal(onPressed: onAction, child: Text(action!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Botão "Seguir" com gradiente quando inativo.
class FollowButton extends StatelessWidget {
  const FollowButton({
    super.key,
    required this.following,
    required this.onTap,
    this.dense = false,
  });
  final bool following;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final pad = dense
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 12);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: following
          ? OutlinedButton.icon(
              key: const ValueKey('on'),
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                padding: pad,
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Seguindo'),
            )
          : DecoratedBox(
              key: const ValueKey('off'),
              decoration: ShapeDecoration(
                gradient: context.jc.accent,
                shape: context.jc.pill(),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  customBorder: context.jc.pill(),
                  onTap: onTap,
                  child: Padding(
                    padding: pad,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: context.jc.onAccent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Seguir',
                          style: TextStyle(
                            color: context.jc.onAccent,
                            fontWeight: FontWeight.w700,
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

/// Pequeno contador com ícone (curtidas, respostas…).
class Stat extends StatelessWidget {
  const Stat(
    this.icon,
    this.label, {
    super.key,
    this.color,
    this.onTap,
    this.semanticLabel,
  });
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.jc.muted;
    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: InkWell(
        borderRadius: context.jc.r(20),
        onTap: onTap,
        // Alvo mínimo de toque do iOS (44 pt), mesmo com o ícone pequeno.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: c),
                if (label.isNotEmpty) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo: as jabuticabas do ícone do app (assets/brand/logo.png), filtradas
/// nos temas monocromáticos.
class JabuLogo extends StatelessWidget {
  const JabuLogo({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    Widget img = Image.asset(
      'assets/brand/logo.png',
      width: size,
      height: size,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
      filterQuality: context.jc.id == JabuThemeId.win95
          ? FilterQuality.none
          : FilterQuality.medium,
    );
    final filter = context.jc.imageFilter;
    if (filter != null) img = ColorFiltered(colorFilter: filter, child: img);
    // Center com fatores 1 impede que pais com largura forçada estiquem o logo.
    return Center(widthFactor: 1, heightFactor: 1, child: img);
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        JabuLogo(size: size * 1.25),
        SizedBox(width: size * .4),
        Text(
          'jabuticaba',
          style: TextStyle(
            fontFamily: context.jc.displayFont,
            fontSize: size * (context.jc.displayFont == 'VT323' ? 1.3 : 1),
            fontWeight: context.jc.displayWeight,
            letterSpacing: context.jc.displayFont == 'Bricolage' ? -.8 : 0,
            color: context.cs.onSurface,
            shadows: context.jc.glow,
          ),
        ),
      ],
    );
  }
}
