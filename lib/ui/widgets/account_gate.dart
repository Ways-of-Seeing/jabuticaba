import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../models/models.dart';
import '../../state/accounts.dart';
import '../screens/fediverse_screen.dart';
import '../theme.dart';
import 'basics.dart';

/// Ações que só funcionam com uma conta conectada.
enum AccountAction {
  like('curtir', Icons.favorite_rounded),
  boost('compartilhar', Icons.repeat_rounded),
  vote('votar', Icons.arrow_upward_rounded),
  post('publicar', Icons.edit_rounded),
  reply('responder', Icons.chat_bubble_rounded),
  follow('seguir no servidor', Icons.person_add_alt_1_rounded),
  favorite('favoritar músicas', Icons.favorite_rounded),
  block('bloquear', Icons.block_rounded),
  mute('silenciar', Icons.volume_off_rounded),
  report('denunciar', Icons.flag_outlined);

  const AccountAction(this.verb, this.icon);
  final String verb;
  final IconData icon;
}

/// Devolve a conta que alcança [network] ou, se não houver, mostra o aviso
/// de conta necessária e devolve `null`.
Future<Account?> requireAccount(
  BuildContext context,
  WidgetRef ref, {
  required AccountAction action,
  Network? network,
}) async {
  // Conta Funkwhale só serve para favoritar música; o resto (seguir, curtir,
  // publicar) passa por Mastodon, Bluesky ou Lemmy.
  bool fits(Account a) =>
      !a.pending &&
      (a.kind != AccountKind.funkwhale || action == AccountAction.favorite) &&
      (network == null
          ? a.kind == AccountKind.mastodon || a.kind == AccountKind.bluesky
          : a.canReach(network));
  final candidates = ref.read(accountsProvider).where(fits).toList();
  final account =
      candidates.where((a) => a.network == network).firstOrNull ??
      candidates.firstOrNull;
  if (account != null) return account;
  await showAccountNeeded(context, ref, action: action, network: network);
  return null;
}

/// Aviso de conta necessária com atalhos para o onboarding do fediverso.
Future<void> showAccountNeeded(
  BuildContext context,
  WidgetRef ref, {
  required AccountAction action,
  Network? network,
}) async {
  final pending = ref.read(accountsProvider).where((a) => a.pending).toList();
  final choice = await showDialog<FediStart>(
    context: context,
    builder: (_) => _AccountNeededDialog(
      action: action,
      network: network,
      pending: pending,
    ),
  );
  if (choice != null && context.mounted) {
    // Para música, os atalhos levam direto ao Funkwhale.
    final start = action == AccountAction.favorite
        ? (choice == FediStart.create
              ? FediStart.music
              : FediStart.musicConnect)
        : choice;
    await openFediverse(context, start: start);
  }
}

class _AccountNeededDialog extends StatelessWidget {
  const _AccountNeededDialog({
    required this.action,
    required this.network,
    required this.pending,
  });
  final AccountAction action;
  final Network? network;
  final List<Account> pending;

  /// Que tipo de conta resolve, explicado em linguagem simples.
  String get _which => switch (network) {
    _ when action == AccountAction.favorite => 'uma conta no Funkwhale',
    Network.funkwhale => 'uma conta no Mastodon ou outro servidor do fediverso (é por ela que você segue artistas do Funkwhale)',
    Network.castopod => 'uma conta no Mastodon ou outro servidor do fediverso (podcasts do Castopod são contas que você segue de lá)',
    Network.bluesky => 'uma conta no Bluesky',
    Network.lemmy => 'uma conta no Lemmy ou no Mastodon',
    null => 'uma conta no Mastodon ou no Bluesky',
    _ => 'uma conta no Mastodon, Pixelfed ou outro servidor do fediverso',
  };

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // O Loops ainda não deixa outros apps agirem em nome de ninguém.
    final unsupported = network == Network.loops;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: ShapeDecoration(
                      gradient: jc.accent,
                      shape: jc.square
                          ? const RoundedRectangleBorder()
                          : const CircleBorder(),
                    ),
                    child: Icon(action.icon, color: jc.onAccent),
                  ),
                  const SizedBox(width: 14),
                  const JabuLogo(size: 44),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                unsupported
                    ? 'O Loops ainda não permite isso'
                    : 'Para ${action.verb}, você precisa de uma conta',
                style: context.tt.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                unsupported
                    ? 'O Loops ainda não deixa outros apps interagirem em nome de alguém. Você pode abrir o vídeo no site do Loops, ou seguir o perfil por aqui.'
                    : 'Sem conta você explora tudo à vontade. Para ${action.verb}, é preciso $_which — '
                          'e o jabuticaba tem um passo a passo para entrar no fediverso: ajuda a escolher um servidor, '
                          'cria a conta com você ou conecta a que você já tem.',
                style: context.tt.bodyMedium?.copyWith(color: jc.muted),
              ),
              if (pending.isNotEmpty && !unsupported) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: jc.panel(color: jc.cardHigh, base: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.mark_email_unread_rounded,
                        size: 20,
                        color: jc.brand,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '@${pending.first.handle} ainda aguarda a confirmação do e-mail. Confirme e toque em "Verificar" na aba Você.',
                          style: context.tt.bodySmall?.copyWith(color: jc.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              if (unsupported)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi'),
                )
              else ...[
                DecoratedBox(
                  decoration: ShapeDecoration(
                    gradient: jc.accent,
                    shape: jc.pill(),
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: jc.onAccent,
                    ),
                    onPressed: () => Navigator.pop(context, FediStart.create),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('Criar minha conta'),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, FediStart.connect),
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Já tenho conta'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Agora não, só explorar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
