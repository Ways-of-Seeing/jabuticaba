import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/accounts.dart';
import '../../state/loaders.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/account_gate.dart';
import '../widgets/basics.dart';
import '../widgets/video.dart';

/// Aba "Clipes": vídeos curtos em tela cheia, deslizando na vertical —
/// Loops, PeerTube, Bluesky e Mastodon juntos.
class ClipsScreen extends ConsumerStatefulWidget {
  const ClipsScreen({super.key});

  @override
  ConsumerState<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends ConsumerState<ClipsScreen> {
  final _clips = <Post>[];
  final _seen = <String>{};
  late Loader<Post> _loader;
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loader = clipsLoader(ref.read(settingsProvider));
    _more();
  }

  Future<void> _more() async {
    if (_loading || _done) return;
    setState(() => _loading = true);
    try {
      final page = await _loader(_cursor);
      if (!mounted) return;
      setState(() {
        for (final p in page.items) {
          if (_seen.add(p.key)) _clips.add(p);
        }
        _cursor = page.cursor;
        _done = page.cursor == null;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_clips.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: _error != null
            ? Theme(
                data: buildTheme(
                  context.jc.dark ? context.jc : JabuStyle.jabuticaba,
                ),
                child: MessageView.error(_error!, () {
                  _error = null;
                  _more();
                }),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
      );
    }
    // Pausa quando outra aba está visível ou algo foi aberto por cima.
    final active =
        ref.watch(currentTabProvider) == 2 &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    return ClipsPager(clips: _clips, active: active, onNearEnd: _more);
  }
}

/// Player aberto a partir de um post ou de uma prévia (tela cheia, com fechar).
class ClipsPlayerScreen extends StatelessWidget {
  const ClipsPlayerScreen({super.key, required this.clips, this.initial = 0});
  final List<Post> clips;
  final int initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ClipsPager(clips: clips, initial: initial, closable: true),
    );
  }
}

class ClipsPager extends StatefulWidget {
  const ClipsPager({
    super.key,
    required this.clips,
    this.initial = 0,
    this.active = true,
    this.closable = false,
    this.onNearEnd,
  });

  final List<Post> clips;
  final int initial;
  final bool active;
  final bool closable;
  final VoidCallback? onNearEnd;

  @override
  State<ClipsPager> createState() => _ClipsPagerState();
}

class _ClipsPagerState extends State<ClipsPager> {
  late final _page = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _muted = false;
  final _focus = FocusNode();
  JabuStyle? _themeStyle;
  ThemeData? _theme;

  ThemeData _themeFor(JabuStyle style) {
    if (!identical(_themeStyle, style) || _theme == null) {
      _themeStyle = style;
      _theme = buildTheme(style);
    }
    return _theme!;
  }

  @override
  void dispose() {
    _page.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.clips.length - 1);
    _page.animateToPage(
      next,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final wide = size.width > size.height * .8;
    final style = context.jc.dark ? context.jc : JabuStyle.jabuticaba;
    return Theme(
      data: _themeFor(style),
      child: KeyboardListener(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: (e) {
          if (e is! KeyDownEvent) return;
          if (e.logicalKey == LogicalKeyboardKey.arrowDown ||
              e.logicalKey == LogicalKeyboardKey.keyJ) {
            _go(1);
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowUp ||
              e.logicalKey == LogicalKeyboardKey.keyK) {
            _go(-1);
          }
          if (e.logicalKey == LogicalKeyboardKey.keyM) {
            setState(() => _muted = !_muted);
          }
          if (e.logicalKey == LogicalKeyboardKey.escape && widget.closable) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // Fundo desfocado com a capa do clipe atual (bonito no desktop).
            if (wide)
              Positioned.fill(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: ImageFiltered(
                    key: ValueKey(_index),
                    imageFilter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                    child: Opacity(
                      opacity: .5,
                      child: NetImage(
                        widget.clips[_index].media
                            .firstWhere((m) => m.isVideo)
                            .thumb,
                      ),
                    ),
                  ),
                ),
              ),
            PageView.builder(
              controller: _page,
              scrollDirection: Axis.vertical,
              itemCount: widget.clips.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                if (i >= widget.clips.length - 4) widget.onNearEnd?.call();
              },
              itemBuilder: (context, i) {
                final clip = widget.clips[i];
                // Mantém player só no clipe atual e vizinhos.
                final near = (i - _index).abs() <= 1;
                final content = _ClipPage(
                  post: clip,
                  active: widget.active && i == _index,
                  loaded: near,
                  muted: _muted,
                  rounded: wide,
                );
                if (!wide) return content;
                // O quadro acompanha a proporção do vídeo: vertical para
                // Loops, largo para PeerTube.
                final aspect =
                    (clip.media.firstWhere((m) => m.isVideo).aspect ?? 9 / 16)
                        .clamp(9 / 16, 16 / 9);
                var h = size.height - 32;
                var w = h * aspect;
                if (w > size.width - 180) {
                  w = size.width - 180;
                  h = w / aspect;
                }
                return Center(
                  child: SizedBox(height: h, width: w, child: content),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    if (widget.closable)
                      _RoundButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.pop(context),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text(
                          'Clipes',
                          style: context.tt.headlineSmall?.copyWith(
                            color: Colors.white,
                            shadows: const [Shadow(blurRadius: 12)],
                          ),
                        ),
                      ),
                    const Spacer(),
                    _RoundButton(
                      icon: _muted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                      onTap: () => setState(() => _muted = !_muted),
                    ),
                  ],
                ),
              ),
            ),
            if (wide)
              Positioned(
                right: 24,
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundButton(
                      icon: Icons.keyboard_arrow_up_rounded,
                      onTap: () => _go(-1),
                    ),
                    const SizedBox(height: 12),
                    _RoundButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onTap: () => _go(1),
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

class _ClipPage extends ConsumerWidget {
  const _ClipPage({
    required this.post,
    required this.active,
    required this.loaded,
    required this.muted,
    required this.rounded,
  });

  final Post post;
  final bool active;
  final bool loaded;
  final bool muted;
  final bool rounded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = post.media.firstWhere((m) => m.isVideo);
    final vertical = (media.aspect ?? .56) < 1;
    final person = Community(
      id: post.author.handle,
      kind: CommunityKind.person,
      network: post.network,
      name: post.author.handle,
      title: post.author.displayName,
      avatar: post.author.avatar,
    );
    final following = ref.watch(
      settingsProvider.select((s) => s.isFollowing(person.key)),
    );
    final caption = (post.title?.isNotEmpty ?? false) ? post.title! : post.text;

    final page = Stack(
      fit: StackFit.expand,
      children: [
        if (loaded)
          VideoSurface(
            post: post,
            active: active,
            muted: muted,
            fit: vertical ? BoxFit.cover : BoxFit.contain,
          )
        else
          NetImage(media.thumb, fit: vertical ? BoxFit.cover : BoxFit.contain),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, .18, .6, 1],
                colors: [
                  Colors.black45,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 90,
          child: Column(
            children: [
              GestureDetector(
                onTap: () => openAuthor(context, post.author),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Avatar(
                        url: post.author.avatar,
                        size: 46,
                        label: post.author.displayName,
                      ),
                    ),
                    Positioned(
                      bottom: -10,
                      child: GestureDetector(
                        onTap: () => ref
                            .read(settingsProvider.notifier)
                            .toggleFollow(person),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: following ? Colors.white : context.jc.hot,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            following ? Icons.check_rounded : Icons.add_rounded,
                            size: 16,
                            color: following ? context.jc.hot : Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _SideAction(
                icon: Icons.favorite_rounded,
                label: compact(post.likes),
                onTap: () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final account = await requireAccount(
                    context,
                    ref,
                    action: AccountAction.like,
                    network: post.network,
                  );
                  if (account == null) return;
                  try {
                    await ref.read(accountsProvider.notifier).like(post);
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('Curtido ✓'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    messenger?.showSnackBar(
                      SnackBar(content: Text('Não deu: $e')),
                    );
                  }
                },
              ),
              _SideAction(
                icon: Icons.chat_bubble_rounded,
                label: compact(post.replies),
              ),
              if (post.views != null)
                _SideAction(
                  icon: Icons.visibility_rounded,
                  label: compact(post.views),
                ),
              _SideAction(
                icon: Icons.ios_share_rounded,
                label: 'Abrir',
                onTap: post.url == null ? null : () => openUrl(post.url!),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 84,
          bottom: 28,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.author.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    NetworkPill(post.network, dense: true, onMedia: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${post.author.handle} · ${timeAgo(post.createdAt)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                  maxLines: 1,
                ),
                if (caption.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    caption.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (post.html != null && caption.trim().isEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    htmlToText(post.html),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      height: 1.35,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    return Padding(
      padding: rounded
          ? const EdgeInsets.symmetric(vertical: 16)
          : EdgeInsets.zero,
      child: rounded
          ? ClipRRect(borderRadius: context.jc.r(28), child: page)
          : page,
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 32,
              shadows: const [Shadow(blurRadius: 10, color: Colors.black54)],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                shadows: [Shadow(blurRadius: 8)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Material(
          color: Colors.white.withValues(alpha: .14),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
