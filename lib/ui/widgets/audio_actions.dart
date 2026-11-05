import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../models/audio.dart';
import '../../models/models.dart';
import '../../services/account_api.dart';
import '../../state/accounts.dart';
import '../../state/settings.dart';
import 'account_gate.dart';

void _say(ScaffoldMessengerState? m, String text) => m?.showSnackBar(
  SnackBar(content: Text(text), duration: const Duration(seconds: 3)),
);

/// Favorita uma faixa com a conta Funkwhale; sem ela, mostra o aviso de conta.
Future<void> favoriteTrack(
  BuildContext context,
  WidgetRef ref,
  AudioItem item,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final account = ref
      .read(accountsProvider)
      .where((a) => !a.pending && a.kind == AccountKind.funkwhale)
      .firstOrNull;
  if (account == null) {
    await showAccountNeeded(
      context,
      ref,
      action: AccountAction.favorite,
      network: Network.funkwhale,
    );
    return;
  }
  try {
    await ref
        .read(accountsProvider.notifier)
        .run(account, (a) => FunkwhaleAccountApi.favorite(a, item));
    _say(messenger, 'Nos seus favoritos em ${account.server} ♥');
  } catch (e) {
    _say(messenger, 'Não deu: $e');
  }
}

/// Segue pelo fediverso quem publicou a faixa ou o podcast (precisa de uma
/// conta Mastodon ou compatível).
Future<void> followUploader(
  BuildContext context,
  WidgetRef ref,
  AudioItem item,
) async {
  final handle = item.uploaderHandle;
  if (handle == null) return;
  await followHandle(
    context,
    ref,
    handle: handle,
    name: item.artist,
    network: item.network,
  );
}

Future<void> followHandle(
  BuildContext context,
  WidgetRef ref, {
  required String handle,
  required String name,
  required Network network,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final account = await requireAccount(
    context,
    ref,
    action: AccountAction.follow,
    network: network,
  );
  if (account == null) return;
  try {
    await ref
        .read(accountsProvider.notifier)
        .run(
          account,
          (a) => AccountApi.followPerson(
            a,
            Author(id: handle, name: name, handle: handle, network: network),
          ),
        );
    _say(messenger, 'Seguindo @$handle com @${account.handle} ✓');
  } catch (e) {
    _say(messenger, 'Não deu: $e');
  }
}

/// Assinar um podcast: salva no aparelho e, com conta, segue pelo fediverso.
Future<void> subscribeShow(
  BuildContext context,
  WidgetRef ref,
  Show show,
) async {
  final community = show.asCommunity();
  final settings = ref.read(settingsProvider.notifier);
  final already = ref.read(settingsProvider).isFollowing(community.key);
  settings.toggleFollow(community);
  if (already || show.handle == null) return;
  final hasAccount =
      ref.read(accountsProvider.notifier).forNetwork(Network.castopod) != null;
  if (!hasAccount) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text(
          'Inscrição salva no aparelho. Com uma conta do fediverso, você também recebe e comenta os episódios por lá.',
        ),
      ),
    );
    return;
  }
  await followHandle(
    context,
    ref,
    handle: show.handle!,
    name: show.title,
    network: Network.castopod,
  );
}
