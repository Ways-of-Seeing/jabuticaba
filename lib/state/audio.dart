import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/http.dart';
import '../models/account.dart';
import '../models/audio.dart';
import '../services/account_api.dart';
import '../services/castopod.dart';
import '../services/funkwhale.dart';
import 'accounts.dart';

/// Álbuns recentes de um pod (`null` = todos os pods, intercalados).
final albumsProvider = FutureProvider.family<List<Album>, String?>((
  ref,
  host,
) async {
  final hosts = host == null ? FunkwhaleApi.pods : [host];
  final lists = await Future.wait([
    for (final h in hosts)
      FunkwhaleApi.albums(h).then((p) => p.items).catchError((_) => <Album>[]),
  ]);
  return interleave(lists).where((a) => a.title != '[Unknown Album]').toList();
});

/// Faixas recentes (ou resultado de busca) de um pod ou de todos.
final tracksProvider =
    FutureProvider.family<List<AudioItem>, (String?, String)>((
      ref,
      args,
    ) async {
      final (host, query) = args;
      final hosts = host == null ? FunkwhaleApi.pods : [host];
      final lists = await Future.wait([
        for (final h in hosts)
          FunkwhaleApi.tracks(
            h,
            query: query.isEmpty ? null : query,
          ).then((p) => p.items).catchError((_) => <AudioItem>[]),
      ]);
      return interleave(lists);
    });

final albumTracksProvider = FutureProvider.family<List<AudioItem>, Album>((
  ref,
  album,
) async {
  final page = await FunkwhaleApi.tracks(album.host, album: album.id);
  return page.items;
});

/// Favoritos da primeira conta Funkwhale conectada.
final musicFavoritesProvider = FutureProvider<List<AudioItem>>((ref) async {
  final account = ref
      .watch(accountsProvider)
      .where((a) => !a.pending && a.kind == AccountKind.funkwhale)
      .firstOrNull;
  if (account == null) return const [];
  return ref
      .read(accountsProvider.notifier)
      .run(account, FunkwhaleAccountApi.favorites);
});

final podcastIndexProvider = FutureProvider<List<Show>>(
  (ref) => CastopodApi.index(),
);

/// Destaques do Explorar: português primeiro, depois os mais ouvidos.
final popularShowsProvider = FutureProvider<List<Show>>((ref) async {
  final all = await ref.watch(podcastIndexProvider.future);
  int score(Show s) =>
      (s.language == 'pt' ? 100000 : 0) +
      s.popularity * 100 +
      (s.lastEpisodeAt?.year ?? 0) -
      2000;
  return ([
    ...all.where((s) => s.artwork != null),
  ]..sort((a, b) => score(b).compareTo(score(a)))).take(16).toList();
});

final podcastFeedProvider =
    FutureProvider.family<(Show, List<AudioItem>), Show>(
      (ref, show) => CastopodApi.feed(show),
    );

const languageNames = {
  'pt': 'Português',
  'en': 'English',
  'es': 'Español',
  'fr': 'Français',
  'de': 'Deutsch',
  'it': 'Italiano',
  'nl': 'Nederlands',
  'ca': 'Català',
  'pl': 'Polski',
  'ja': '日本語',
};

const categoryNames = {
  'technology': 'Tecnologia',
  'society': 'Sociedade',
  'culture': 'Cultura',
  'news': 'Notícias',
  'education': 'Educação',
  'arts': 'Artes',
  'music': 'Música',
  'comedy': 'Humor',
  'business': 'Negócios',
  'religion': 'Religião',
  'spirituality': 'Espiritualidade',
  'leisure': 'Lazer',
  'games': 'Games',
  'science': 'Ciência',
  'health': 'Saúde',
  'history': 'História',
  'sports': 'Esportes',
  'politics': 'Política',
  'books': 'Livros',
  'fiction': 'Ficção',
  'tv': 'TV',
  'film': 'Cinema',
  'kids': 'Crianças',
  'family': 'Família',
};
