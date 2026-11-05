import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../models/audio.dart';

/// Player de áudio do app inteiro (música e podcasts). Usa o mesmo motor
/// nativo dos vídeos (AVPlayer, ExoPlayer…), que toca MP3/AAC/HLS.
class AudioPlayerService extends ChangeNotifier {
  AudioPlayerService._();
  static final instance = AudioPlayerService._();

  VideoPlayerController? _c;
  List<AudioItem> _queue = const [];
  int _index = 0;
  bool _loading = false;
  Object? _error;
  double _speed = 1;

  List<AudioItem> get queue => _queue;
  int get index => _index;
  AudioItem? get current => _queue.isEmpty ? null : _queue[_index];
  bool get loading => _loading;
  Object? get error => _error;
  double get speed => _speed;
  bool get playing => _c?.value.isPlaying ?? false;
  Duration get position => _c?.value.position ?? Duration.zero;
  Duration get duration {
    final d = _c?.value.duration ?? Duration.zero;
    return d > Duration.zero ? d : (current?.duration ?? Duration.zero);
  }

  bool get hasNext => _index < _queue.length - 1;
  bool get hasPrevious => _index > 0;

  /// Toca [items] a partir de [start]. Se for o mesmo item que já toca,
  /// só alterna pausa/play.
  Future<void> play(List<AudioItem> items, [int start = 0]) async {
    if (items.isEmpty) return;
    if (current?.key == items[start].key && _c != null) {
      _queue = items;
      _index = start;
      return toggle();
    }
    _queue = List.unmodifiable(items);
    _index = start;
    await _load();
  }

  Future<void> _load() async {
    final item = current;
    if (item == null) return;
    final old = _c;
    _c = null;
    old?.removeListener(_tick);
    await old?.dispose();
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final c = VideoPlayerController.networkUrl(
        Uri.parse(item.streamUrl),
        videoPlayerOptions: VideoPlayerOptions(allowBackgroundPlayback: true),
      );
      _c = c;
      await c.initialize();
      if (_c != c) return; // outra faixa foi escolhida enquanto carregava
      c.addListener(_tick);
      await c.setPlaybackSpeed(_speed);
      await c.play();
    } catch (e) {
      _error = e;
    }
    _loading = false;
    notifyListeners();
  }

  bool _advancing = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  void _tick() {
    final v = _c?.value;
    if (v == null) return;
    // Ao terminar, segue para a próxima da fila.
    if (!_advancing &&
        v.isInitialized &&
        v.duration > Duration.zero &&
        v.position >= v.duration - const Duration(milliseconds: 300) &&
        !v.isPlaying) {
      _advancing = true;
      if (hasNext) {
        _index++;
        _load().whenComplete(() => _advancing = false);
      } else {
        _advancing = false;
        notifyListeners();
      }
      return;
    }
    // A barra de progresso não precisa de mais que ~4 atualizações por segundo.
    final now = DateTime.now();
    if (now.difference(_lastNotify) > const Duration(milliseconds: 250)) {
      _lastNotify = now;
      notifyListeners();
    }
  }

  Future<void> toggle() async {
    final c = _c;
    if (c == null) return _load();
    c.value.isPlaying ? await c.pause() : await c.play();
    notifyListeners();
  }

  Future<void> pause() async {
    if (_c?.value.isPlaying ?? false) {
      await _c!.pause();
      notifyListeners();
    }
  }

  Future<void> next() async {
    if (!hasNext) return;
    _index++;
    await _load();
  }

  Future<void> previous() async {
    // Como nos players comuns: volta ao início se já passou de 3 s.
    if (position > const Duration(seconds: 3) || !hasPrevious) {
      return seek(Duration.zero);
    }
    _index--;
    await _load();
  }

  Future<void> seek(Duration to) async {
    await _c?.seekTo(to);
    notifyListeners();
  }

  Future<void> skip(Duration by) =>
      seek(position + by < Duration.zero ? Duration.zero : position + by);

  Future<void> setSpeed(double s) async {
    _speed = s;
    await _c?.setPlaybackSpeed(s);
    notifyListeners();
  }

  Future<void> stop() async {
    final c = _c;
    _c = null;
    c?.removeListener(_tick);
    await c?.dispose();
    _queue = const [];
    _index = 0;
    notifyListeners();
  }
}
