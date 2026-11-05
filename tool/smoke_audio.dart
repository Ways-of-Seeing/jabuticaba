// ignore_for_file: avoid_print
// Verificação rápida das fontes de áudio contra os servidores reais.
// Uso: dart run tool/smoke_audio.dart
import 'package:jabuticaba/services/castopod.dart';
import 'package:jabuticaba/services/funkwhale.dart';

Future<void> main() async {
  final shows = await CastopodApi.index();
  print('Castopod: ${shows.length} podcasts; pt=${shows.where((s) => s.language == 'pt').length}');
  final top = ([...shows]..sort((a, b) => b.popularity.compareTo(a.popularity))).first;
  print('  mais popular: ${top.title} · @${top.handle} · ${top.latest?.streamUrl}');
  final (full, eps) = await CastopodApi.feed(top);
  print('  feed: ${eps.length} episódios; 1º: "${eps.first.title}" ${eps.first.duration} ${eps.first.publishedAt}');
  for (final pod in FunkwhaleApi.pods) {
    try {
      final t = await FunkwhaleApi.tracks(pod);
      final a = await FunkwhaleApi.albums(pod);
      final f = t.items.isEmpty ? null : t.items.first;
      print('Funkwhale $pod: ${t.items.length} faixas, ${a.items.length} álbuns; 1ª: ${f?.title} — ${f?.artist} (${f?.duration}) handle=${f?.uploaderHandle}');
    } catch (e) {
      print('Funkwhale $pod: ERRO $e');
    }
  }
}
