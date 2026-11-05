import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../ui/theme.dart';
import 'interests.dart';

/// Sobrescrito em `main()` depois que o SharedPreferences carrega.
final prefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

class Settings {
  const Settings({
    this.onboarded = false,
    this.interests = const {},
    this.follows = const [],
    this.theme = JabuThemeId.system,
    this.showSensitive = false,
  });

  final bool onboarded;
  final Set<String> interests;

  /// "Seguir" local: sem conta, o jabuticaba guarda o que você acompanha.
  final List<Community> follows;
  final JabuThemeId theme;
  final bool showSensitive;

  List<Interest> get chosen => [for (final id in interests) ?interestById(id)];

  /// Hashtags derivadas dos interesses (no máximo uma por interesse, para
  /// não multiplicar requisições).
  List<String> get interestTags => [for (final i in chosen) i.tags.first];

  bool isFollowing(String key) => follows.any((c) => c.key == key);

  Settings copyWith({
    bool? onboarded,
    Set<String>? interests,
    List<Community>? follows,
    JabuThemeId? theme,
    bool? showSensitive,
  }) => Settings(
    onboarded: onboarded ?? this.onboarded,
    interests: interests ?? this.interests,
    follows: follows ?? this.follows,
    theme: theme ?? this.theme,
    showSensitive: showSensitive ?? this.showSensitive,
  );
}

class SettingsNotifier extends Notifier<Settings> {
  late SharedPreferences _prefs;

  @override
  Settings build() {
    _prefs = ref.watch(prefsProvider);
    List<Community> follows = const [];
    try {
      final raw = _prefs.getString('follows');
      if (raw != null) {
        follows = [
          for (final j in jsonDecode(raw) as List)
            Community.fromJson(j as Map<String, dynamic>),
        ];
      }
    } catch (_) {}
    return Settings(
      onboarded: _prefs.getBool('onboarded') ?? false,
      interests: (_prefs.getStringList('interests') ?? const []).toSet(),
      follows: follows,
      theme:
          JabuThemeId.values.asNameMap()[_prefs.getString('theme')] ??
          JabuThemeId.system,
      showSensitive: _prefs.getBool('showSensitive') ?? false,
    );
  }

  void finishOnboarding(Set<String> chosen) {
    state = state.copyWith(onboarded: true, interests: chosen);
    _prefs.setBool('onboarded', true);
    _prefs.setStringList('interests', chosen.toList());
  }

  void toggleInterest(String id) {
    final next = {...state.interests};
    next.contains(id) ? next.remove(id) : next.add(id);
    state = state.copyWith(interests: next);
    _prefs.setStringList('interests', next.toList());
  }

  void toggleFollow(Community c) {
    final exists = state.isFollowing(c.key);
    final next = exists
        ? state.follows.where((f) => f.key != c.key).toList()
        : [c, ...state.follows];
    state = state.copyWith(follows: next);
    _prefs.setString('follows', jsonEncode([for (final f in next) f.toJson()]));
  }

  void setTheme(JabuThemeId id) {
    state = state.copyWith(theme: id);
    _prefs.setString('theme', id.name);
  }

  void setShowSensitive(bool v) {
    state = state.copyWith(showSensitive: v);
    _prefs.setBool('showSensitive', v);
  }

  void reset() {
    _prefs.clear();
    state = const Settings();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
