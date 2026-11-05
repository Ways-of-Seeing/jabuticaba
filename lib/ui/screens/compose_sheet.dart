import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account.dart';
import '../../services/account_api.dart';
import '../../state/accounts.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/account_gate.dart';

/// Abre o compositor; sem contas que publiquem, leva ao "Entrar no fediverso".
Future<void> openComposer(BuildContext context, WidgetRef ref) async {
  final usable = ref.read(accountsProvider).where(_canPost).toList();
  if (usable.isEmpty) {
    await showAccountNeeded(context, ref, action: AccountAction.post);
    return;
  }
  await showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const _Composer(),
  );
}

bool _canPost(Account a) =>
    !a.pending &&
    (a.kind == AccountKind.mastodon || a.kind == AccountKind.bluesky);

class _Composer extends ConsumerStatefulWidget {
  const _Composer();

  @override
  ConsumerState<_Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<_Composer> {
  final _text = TextEditingController();
  late Set<String> _selected = {
    for (final a in ref.read(accountsProvider).where(_canPost).take(1)) a.id,
  };
  bool _sending = false;
  List<(Account, String?, Object?)>? _results;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  List<Account> get _targets => ref
      .read(accountsProvider)
      .where((a) => _selected.contains(a.id))
      .toList();

  /// O limite efetivo é o da rede mais restritiva entre as escolhidas.
  int get _limit => _targets.isEmpty
      ? 500
      : _targets.map((a) => a.charLimit).reduce((a, b) => a < b ? a : b);

  Future<void> _send() async {
    setState(() => _sending = true);
    final notifier = ref.read(accountsProvider.notifier);
    final results = await Future.wait([
      for (final a in _targets)
        notifier
            .run(a, (acc) => AccountApi.post(acc, _text.text.trim()))
            .then<(Account, String?, Object?)>((url) => (a, url, null))
            .catchError((Object e) => (a, null, e)),
    ]);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final accounts = ref.watch(accountsProvider).where(_canPost).toList();
    final length = _text.text.characters.length;
    final over = length > _limit;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    if (_results != null) {
      final ok = _results!.where((r) => r.$3 == null).length;
      return Padding(
        padding: EdgeInsets.fromLTRB(22, 4, 22, 24 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ok == _results!.length
                  ? 'Publicado! 🎉'
                  : 'Publicado em $ok de ${_results!.length}',
              style: context.tt.headlineMedium,
            ),
            const SizedBox(height: 14),
            for (final (a, url, err) in _results!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(
                  url: a.avatar,
                  network: a.network,
                  label: a.name,
                ),
                title: Text(
                  '@${a.handle}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  err == null ? 'Enviado' : 'Falhou: $err',
                  maxLines: 2,
                ),
                trailing: url == null
                    ? Icon(
                        err == null
                            ? Icons.check_rounded
                            : Icons.error_outline_rounded,
                        color: err == null ? Jabu.leaf : jc.hot,
                      )
                    : IconButton(
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: () => openUrl(url),
                      ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 4, 22, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(jc.headline('Novo post'), style: context.tt.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Escolha uma ou mais contas — publicamos em todas de uma vez.',
            style: context.tt.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in accounts)
                FilterChip(
                  selected: _selected.contains(a.id),
                  avatar: Avatar(url: a.avatar, size: 22, label: a.name),
                  label: Text('@${a.handle}'),
                  onSelected: (v) => setState(
                    () =>
                        v
                              ? _selected = {..._selected, a.id}
                              : _selected = {..._selected}
                          ..remove(a.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _text,
            autofocus: true,
            minLines: 5,
            maxLines: 12,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'O que está acontecendo?',
              border: OutlineInputBorder(
                borderRadius: jc.r(18),
                borderSide: BorderSide(color: jc.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: jc.r(18),
                borderSide: BorderSide(color: jc.line),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: jc.r(18),
                borderSide: BorderSide(color: jc.brand, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(
                  value: (length / _limit).clamp(0, 1),
                  strokeWidth: 3,
                  backgroundColor: jc.cardHigh,
                  color: over ? jc.hot : jc.brand,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${_limit - length}',
                style: context.tt.labelLarge?.copyWith(
                  color: over ? jc.hot : jc.muted,
                ),
              ),
              if (_targets.any((a) => a.kind == AccountKind.bluesky) &&
                  _limit == 300) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'limite do Bluesky',
                    style: context.tt.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed:
                    _sending ||
                        over ||
                        _text.text.trim().isEmpty ||
                        _selected.isEmpty
                    ? null
                    : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _selected.length > 1
                      ? 'Publicar em ${_selected.length}'
                      : 'Publicar',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
