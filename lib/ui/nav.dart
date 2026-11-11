import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/audio.dart';
import '../models/models.dart';
import 'screens/clips_screen.dart';
import 'screens/community_screen.dart';
import 'screens/podcasts_screen.dart';
import 'screens/post_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/tag_screen.dart';
import 'widgets/media.dart';

/// Navegação central. As telas de conteúdo abrem dentro da aba atual (a barra
/// lateral/inferior continua visível); mídia em tela cheia abre por cima de tudo.
void _push(BuildContext context, Widget page, {bool root = false}) {
  Navigator.of(context, rootNavigator: root).push(
    root
        ? PageRouteBuilder(
            opaque: false,
            barrierColor: Colors.black,
            transitionDuration: const Duration(milliseconds: 260),
            pageBuilder: (_, _, _) => page,
            transitionsBuilder: (_, a, _, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child,
            ),
          )
        : MaterialPageRoute(builder: (_) => page),
  );
}

void openPost(BuildContext context, Post p) {
  if (p.network == Network.loops || (p.network == Network.peertube)) {
    openClips(context, [p], 0);
    return;
  }
  _push(context, PostScreen(post: p));
}

void openAuthor(BuildContext context, Author a) =>
    _push(context, ProfileScreen(author: a));

void openHandle(BuildContext context, String handle, Network network) => _push(
  context,
  ProfileScreen(
    author: Author(id: handle, name: '', handle: handle, network: network),
  ),
);

void openTag(BuildContext context, String tag) =>
    _push(context, TagScreen(tag: tag));

void openCommunity(BuildContext context, Community c) => _push(
  context,
  c.kind == CommunityKind.podcast
      ? PodcastScreen(show: Show.fromCommunity(c))
      : CommunityScreen(community: c),
);

void openTrend(BuildContext context, Trend t) {
  if (t.network == Network.bluesky && t.ref != null) {
    openCommunity(
      context,
      Community(
        id: t.ref!,
        kind: CommunityKind.feed,
        network: Network.bluesky,
        name: t.ref!,
        title: t.name,
        description: t.description,
      ),
    );
  } else {
    openTag(context, t.name);
  }
}

void openMedia(BuildContext context, List<Media> media, int index) =>
    _push(context, MediaViewer(media: media, initial: index), root: true);

void openClips(BuildContext context, List<Post> clips, int index) =>
    _push(context, ClipsPlayerScreen(clips: clips, initial: index), root: true);

/// Só abrimos endereços web. Conteúdo remoto não pode disparar esquemas como
/// `tel:`, `file:` ou deep links de outros apps sem uma ação explícita nossa.
bool isSafeExternalUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty &&
      // Evita links com credenciais embutidas (https://banco@evil.example).
      uri.userInfo.isEmpty;
}

Future<void> openUrl(String url) async {
  if (!isSafeExternalUrl(url)) return;
  final uri = Uri.parse(url.trim());
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // Um aparelho sem navegador não deve derrubar a tela do post.
  }
}
