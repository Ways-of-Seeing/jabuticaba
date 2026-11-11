import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../models/models.dart';
import '../../services/peertube.dart';
import '../../state/player.dart';
import 'basics.dart';

/// Superfície de vídeo: resolve a URL (o PeerTube precisa de uma requisição
/// extra), toca em loop enquanto [active] e mostra a capa até o primeiro frame.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.post,
    required this.active,
    this.fit = BoxFit.contain,
    this.muted = false,
    this.showProgress = true,
  });

  final Post post;
  final bool active;
  final BoxFit fit;
  final bool muted;
  final bool showProgress;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  VideoPlayerController? _c;
  Object? _error;
  bool _paused = false;
  bool _initializing = false;

  Media get _media => widget.post.media.firstWhere((m) => m.isVideo);

  @override
  void initState() {
    super.initState();
    if (widget.active) _init();
  }

  @override
  void didUpdateWidget(VideoSurface old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _paused = false;
    if (widget.active && _c == null && _error == null && !_initializing) {
      _init();
    }
    final c = _c;
    if (c != null && c.value.isInitialized) {
      if (widget.active && !_paused) {
        c.play();
        if (!widget.muted) AudioPlayerService.instance.pause();
      } else {
        c.pause();
      }
      c.setVolume(widget.muted ? 0 : 1);
    }
  }

  Future<void> _init() async {
    if (_initializing) return;
    _initializing = true;
    VideoPlayerController? c;
    try {
      var url = _media.url;
      if (url.isEmpty && widget.post.network == Network.peertube) {
        url = await PeerTubeApi.playableUrl(widget.post);
      }
      c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.setVolume(widget.muted ? 0 : 1);
      _c = c;
      if (widget.active && !_paused) {
        await c.play();
        // Um clipe com som pausa a música ou o podcast.
        if (!widget.muted) AudioPlayerService.instance.pause();
      }
      setState(() {});
    } catch (e) {
      await c?.dispose();
      if (mounted) setState(() => _error = e);
    } finally {
      _initializing = false;
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  void _toggle() {
    final c = _c;
    if (c == null || !c.value.isInitialized) return;
    setState(() {
      _paused = c.value.isPlaying;
      _paused ? c.pause() : c.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final aspect = ready ? c.value.aspectRatio : (_media.aspect ?? 9 / 16);
    return GestureDetector(
      onTap: _toggle,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (_media.previewUrl != null)
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: 1000 * aspect,
                height: 1000,
                child: NetImage(
                  _media.previewUrl,
                  blurhash: _media.blurhash,
                  cacheWidth: 720,
                ),
              ),
            ),
          if (ready)
            FittedBox(
              fit: widget.fit,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: c.value.size.width,
                height: c.value.size.height,
                child: VideoPlayer(c),
              ),
            ),
          if (!ready && _error == null && widget.active)
            const Center(
              child: SizedBox.square(
                dimension: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white70,
                ),
              ),
            ),
          if (_error != null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    color: Colors.white70,
                    size: 40,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Este vídeo não pôde ser reproduzido',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          if (_paused)
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 46,
                ),
              ),
            ),
          if (ready && widget.showProgress)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                c,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
