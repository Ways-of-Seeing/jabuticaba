import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'state/accounts.dart';
import 'state/demo.dart';
import 'state/settings.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  if (demoMode) await prepareDemo(prefs);
  final accounts = await TokenStore.load();
  runApp(
    ProviderScope(
      // Sem repetição automática: as telas mostram o erro com "Tentar de novo".
      retry: (_, _) => null,
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        initialAccountsProvider.overrideWithValue(accounts),
      ],
      child: const JabuticabaApp(),
    ),
  );
}

class JabuticabaApp extends ConsumerWidget {
  const JabuticabaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeId = ref.watch(settingsProvider.select((s) => s.theme));
    final fixed = themeId == JabuThemeId.system
        ? null
        : buildTheme(JabuStyle.of(themeId));
    final onboarded = ref.watch(settingsProvider.select((s) => s.onboarded));
    return MaterialApp(
      title: 'jabuticaba',
      debugShowCheckedModeBanner: false,
      // "Sistema" alterna Polpa/Jabuticaba; os outros temas são fixos.
      theme: fixed ?? buildTheme(JabuStyle.polpa),
      darkTheme: fixed ?? buildTheme(JabuStyle.jabuticaba),
      themeMode: fixed == null ? ThemeMode.system : ThemeMode.light,
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        child: onboarded
            ? AppShell(initialTab: demoTab)
            : const OnboardingScreen(),
      ),
    );
  }
}
