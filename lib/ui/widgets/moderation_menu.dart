import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http.dart';
import '../../models/models.dart';
import '../../services/moderation.dart';
import '../../state/accounts.dart';
import '../theme.dart';
import 'account_gate.dart';

/// Menu de denúncia e ações de autor, compartilhado pelo post e pelo perfil.
class ModerationMenu extends ConsumerStatefulWidget {
  const ModerationMenu({super.key, required this.author, this.post});

  final Author author;
  final Post? post;

  @override
  ConsumerState<ModerationMenu> createState() => _ModerationMenuState();
}

class _ModerationMenuState extends ConsumerState<ModerationMenu> {
  bool _busy = false;

  bool get _canBlock => ModerationApi.canBlock(widget.author.network);
  bool get _canMute => ModerationApi.canMute(widget.author.network);
  bool get _canReport =>
      ModerationApi.canReport(widget.author.network) &&
      (widget.post != null || widget.author.network != Network.lemmy);

  Future<void> _run(String action) async {
    if (_busy) return;
    final account = await requireAccount(
      context,
      ref,
      action: switch (action) {
        'block' => AccountAction.block,
        'mute' => AccountAction.mute,
        _ => AccountAction.report,
      },
      network: widget.author.network,
    );
    if (account == null || !mounted) return;

    if (action == 'block') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Bloquear esta pessoa?'),
          content: Text(
            '@${widget.author.handle} deixa de aparecer para você, e a conta '
            'é bloqueada no servidor. Para desbloquear depois, use o site da '
            'sua rede.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('Bloquear'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    ModerationInput? input;
    if (action == 'report') {
      input = await showDialog<ModerationInput>(
        context: context,
        builder: (_) => _ReportDialog(showPostOption: widget.post != null),
      );
      if (input == null || !mounted) return;
    }

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(accountsProvider.notifier).run(account, (a) async {
        switch (action) {
          case 'block':
            await ModerationApi.block(a, widget.author);
          case 'mute':
            await ModerationApi.mute(a, widget.author);
          default:
            await ModerationApi.report(
              a,
              author: widget.author,
              post: widget.post,
              reason: input!.reason,
              detail: input.detail,
            );
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(switch (action) {
            'block' => 'Pessoa bloqueada',
            'mute' => 'Pessoa silenciada',
            _ => 'Denúncia enviada para a moderação',
          }),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Não deu: ${e is ApiException ? e.message : e}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <PopupMenuEntry<String>>[
      if (_canReport)
        const PopupMenuItem(
          value: 'report',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.flag_outlined),
            title: Text('Denunciar'),
          ),
        ),
      if (_canMute)
        const PopupMenuItem(
          value: 'mute',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.volume_off_rounded),
            title: Text('Silenciar'),
          ),
        ),
      if (_canBlock)
        const PopupMenuItem(
          value: 'block',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.block_rounded),
            title: Text('Bloquear'),
          ),
        ),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Mais ações',
      enabled: !_busy,
      onSelected: _run,
      itemBuilder: (_) => items,
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: context.jc.muted),
    );
  }
}

class ModerationInput {
  const ModerationInput(this.reason, this.detail);
  final ReportReason reason;
  final String? detail;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.showPostOption});
  final bool showPostOption;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _detail = TextEditingController();
  ReportReason _reason = ReportReason.spam;

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Denunciar'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.showPostOption
                  ? 'A denúncia vai para a moderação do seu servidor, junto '
                        'com este post.'
                  : 'A denúncia vai para a moderação do seu servidor.',
              style: context.tt.bodySmall?.copyWith(color: context.jc.muted),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ReportReason>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Motivo'),
              items: [
                for (final r in ReportReason.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (r) => setState(() => _reason = r ?? _reason),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _detail,
              minLines: 2,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Detalhes (opcional)',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            ModerationInput(_reason, _detail.text.trim()),
          ),
          child: const Text('Enviar denúncia'),
        ),
      ],
    );
  }
}
