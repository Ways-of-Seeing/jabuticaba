import 'package:shared_preferences/shared_preferences.dart';

/// Modo demonstração, para capturas de tela e apresentações:
/// `flutter build web --dart-define=DEMO=true` e então abrir com
/// `?tema=matrix&aba=musica&onboarding=1`. Fora desse build, nada aqui roda.
const demoMode = bool.fromEnvironment('DEMO');

const _tabs = {
  'explorar': 0,
  'fio': 1,
  'clipes': 2,
  'fotos': 3,
  'musica': 4,
  'podcasts': 5,
  'comunidades': 6,
  'voce': 7,
};

int get demoTab => demoMode ? _tabs[Uri.base.queryParameters['aba']] ?? 0 : 0;

/// Pula o onboarding (a menos que `onboarding=1`) com interesses de exemplo
/// e aplica o tema pedido na URL.
Future<void> prepareDemo(SharedPreferences prefs) async {
  final q = Uri.base.queryParameters;
  await prefs.setBool('onboarded', q['onboarding'] != '1');
  await prefs.setStringList('interests', const [
    'arte',
    'foto',
    'musica',
    'brasil',
    'natureza',
  ]);
  await prefs.setString('theme', q['tema'] ?? 'jabuticaba');
}
