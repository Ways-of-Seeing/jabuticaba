import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../models/models.dart';
import '../../state/accounts.dart';
import '../../state/interests.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/theme_picker.dart';
import 'explore_screen.dart';
import 'fediverse_screen.dart';
import 'onboarding_screen.dart';

/// Aba "Você": contas, visual, o que você segue, interesses e preferências.
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final accounts = ref.watch(accountsProvider);
    final jc = context.jc;

    Widget card(List<Widget> children) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: jc.panel(),
      clipBehavior: jc.bevel ? Clip.none : Clip.antiAlias,
      child: Column(children: children),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(jc.headline('Você')),
        toolbarHeight: 64,
        titleTextStyle: context.tt.headlineLarge?.copyWith(
          color: jc.onTitleBar,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              if (accounts.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: jc.accentPanel(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.rocket_launch_rounded,
                              color: jc.onAccent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Entre no fediverso',
                                style: TextStyle(
                                  color: jc.onAccent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 19,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Conecte suas contas (Mastodon, Pixelfed, Bluesky, Lemmy) ou crie uma nova com ajuda. '
                          'Com conta, você curte, compartilha, segue e publica direto daqui.',
                          style: TextStyle(color: jc.onAccent, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: jc.onAccent,
                                foregroundColor: jc.dark
                                    ? Colors.black
                                    : jc.brand,
                              ),
                              onPressed: () => openFediverse(
                                context,
                                start: FediStart.connect,
                              ),
                              child: const Text('Já tenho conta'),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: jc.onAccent,
                                side: BorderSide(
                                  color: jc.onAccent.withValues(alpha: .7),
                                ),
                              ),
                              onPressed: () => openFediverse(
                                context,
                                start: FediStart.create,
                              ),
                              child: const Text('Criar uma conta'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SectionHeader(
                  'Contas',
                  emoji: '🔑',
                  subtitle:
                      '${accounts.length} conectada${accounts.length == 1 ? '' : 's'}',
                  action: 'Adicionar',
                  onAction: () => openFediverse(context),
                ),
                card([for (final a in accounts) _AccountTile(account: a)]),
              ],
              SectionHeader('Visual', emoji: '🎨', subtitle: s.theme.blurb),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ThemePicker(),
              ),
              SectionHeader(
                'Seguindo',
                emoji: '💜',
                subtitle: '${s.follows.length} itens salvos neste aparelho',
              ),
              if (s.follows.isEmpty)
                card([
                  const ListTile(
                    leading: Text('🌱', style: TextStyle(fontSize: 26)),
                    title: Text('Nada por enquanto'),
                    subtitle: Text(
                      'Toque em "Seguir" em perfis, hashtags, comunidades, feeds e servidores.',
                    ),
                  ),
                ])
              else
                card([
                  for (final f in s.follows)
                    ListTile(
                      leading: f.kind == CommunityKind.hashtag
                          ? Container(
                              width: 40,
                              height: 40,
                              decoration: ShapeDecoration(
                                gradient: jc.accent,
                                shape: jc.square
                                    ? const RoundedRectangleBorder()
                                    : RoundedRectangleBorder(
                                        borderRadius: jc.r(12),
                                      ),
                              ),
                              child: Center(
                                child: Text(
                                  '#',
                                  style: TextStyle(
                                    color: jc.onAccent,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            )
                          : Avatar(
                              url: f.avatar,
                              size: 40,
                              network: f.network,
                              label: f.displayTitle,
                              square: f.kind != CommunityKind.person,
                            ),
                      title: Text(
                        f.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('${f.kind.label} · ${f.network.label}'),
                      trailing: IconButton(
                        tooltip: 'Deixar de seguir',
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () => n.toggleFollow(f),
                      ),
                      onTap: () => switch (f.kind) {
                        CommunityKind.hashtag => openTag(context, f.name),
                        CommunityKind.person => openHandle(
                          context,
                          f.name,
                          f.network,
                        ),
                        _ => openCommunity(context, f),
                      },
                    ),
                ]),
              const SectionHeader(
                'Seus interesses',
                emoji: '✨',
                subtitle: 'Personalizam o Explorar, os Clipes e as Fotos',
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final i in interests)
                      InterestChip(
                        interest: i,
                        selected: s.interests.contains(i.id),
                        onTap: () => n.toggleInterest(i.id),
                      ),
                  ],
                ),
              ),
              const SectionHeader('Preferências', emoji: '⚙️'),
              card([
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_rounded),
                  title: const Text('Mostrar mídia sensível'),
                  subtitle: const Text(
                    'Por padrão, fica desfocada até você tocar',
                  ),
                  value: s.showSensitive,
                  onChanged: n.setShowSensitive,
                ),
                ListTile(
                  leading: const Icon(Icons.school_rounded),
                  title: const Text('Como funciona o fediverso'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showFediverseGuide(context),
                ),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded),
                  title: const Text('Recomeçar do zero'),
                  subtitle: const Text(
                    'Apaga interesses e itens seguidos deste aparelho (as contas continuam)',
                  ),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Recomeçar?'),
                        content: const Text(
                          'Seus interesses e tudo o que você segue serão apagados deste aparelho.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Apagar'),
                          ),
                        ],
                      ),
                    );
                    if (ok ?? false) n.reset();
                  },
                ),
              ]),
              const SizedBox(height: 28),
              const Center(child: Wordmark(size: 18)),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'versão 0.2 · feito com 💜 e protocolos abertos',
                  style: context.tt.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerStatefulWidget {
  const _AccountTile({required this.account});
  final Account account;

  @override
  ConsumerState<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends ConsumerState<_AccountTile> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.account;
    final notifier = ref.read(accountsProvider.notifier);
    return ListTile(
      leading: Avatar(
        url: a.avatar,
        size: 42,
        network: a.network,
        label: a.name,
      ),
      title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        a.pending ? 'Aguardando confirmação do e-mail' : '@${a.handle}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: a.pending
          ? null
          : () => openAuthor(
              context,
              Author(
                id: a.kind == AccountKind.bluesky ? a.userId : a.handle,
                name: a.name,
                handle: a.handle,
                network: a.network,
                avatar: a.avatar,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a.pending)
            TextButton(
              onPressed: _checking
                  ? null
                  : () async {
                      setState(() => _checking = true);
                      final ok = await notifier.checkPending(a);
                      if (!context.mounted) return;
                      setState(() => _checking = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Conta liberada! 🎉'
                                : 'Ainda não confirmada. Veja seu e-mail.',
                          ),
                        ),
                      );
                    },
              child: Text(_checking ? '…' : 'Verificar'),
            )
          else
            NetworkPill(a.network, dense: true),
          IconButton(
            tooltip: 'Desconectar',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Desconectar conta?'),
                  content: Text(
                    '@${a.handle} sai do jabuticaba. A conta continua existindo no servidor.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Desconectar'),
                    ),
                  ],
                ),
              );
              if (ok ?? false) notifier.remove(a);
            },
          ),
        ],
      ),
    );
  }
}
