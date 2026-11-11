import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../state/accounts.dart';
import '../nav.dart';
import '../theme.dart';
import 'account_gate.dart';
import 'basics.dart';
import 'media.dart';
import 'moderation_menu.dart';
import 'rich_content.dart';

/// Post no fio: cabeçalho com autor e rede, texto, mídia, link e ações.
class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.expanded = false,
    this.depth = 0,
  });
  final Post post;

  /// Na tela de detalhe mostramos o texto inteiro e mídia maior.
  final bool expanded;

  /// Recuo para respostas encadeadas.
  final int depth;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showSpoiler = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final jc = context.jc;
    final hideBody = p.spoiler != null && !_showSpoiler;
    final reply = widget.depth > 0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.boostedBy != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.repeat_rounded, size: 15, color: jc.muted),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '${p.boostedBy!.displayName} compartilhou',
                    style: context.tt.labelMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        _Header(post: p, small: reply),
        if (p.community != null && p.network == Network.lemmy)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _CommunityChip(p.community!),
          ),
        if (p.title?.isNotEmpty ?? false) ...[
          const SizedBox(height: 10),
          Text(p.title!, style: context.tt.titleLarge?.copyWith(height: 1.25)),
        ],
        if (p.spoiler != null) ...[
          const SizedBox(height: 10),
          InkWell(
            borderRadius: context.jc.r(14),
            onTap: () => setState(() => _showSpoiler = !_showSpoiler),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.jc.hot.withValues(alpha: .1),
                borderRadius: context.jc.r(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: context.jc.hot,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(p.spoiler!, style: context.tt.titleSmall),
                  ),
                  Text(
                    _showSpoiler ? 'Ocultar' : 'Mostrar',
                    style: context.tt.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
        if (!hideBody) ...[
          if ((p.html?.isNotEmpty ?? false) || p.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            RichContent(
              html: p.html,
              text: p.network == Network.lemmy ? stripMarkdown(p.text) : p.text,
              network: p.network,
              maxLines: widget.expanded ? null : (p.title != null ? 4 : 10),
              style: reply ? context.tt.bodyMedium : null,
            ),
          ],
          if (p.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            MediaGrid(post: p, maxHeight: widget.expanded ? 720 : 520),
          ],
          if (p.card != null && p.media.isEmpty) ...[
            const SizedBox(height: 12),
            LinkCardView(p.card!, compact: reply),
          ],
        ],
        const SizedBox(height: 6),
        _Actions(post: p),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.expanded ? null : () => openPost(context, p),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16 + widget.depth * 18.0,
            reply ? 10 : 16,
            16,
            6,
          ),
          child: reply
              ? Container(
                  padding: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    border: Border(left: BorderSide(color: jc.line, width: 2)),
                  ),
                  child: body,
                )
              : body,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post, this.small = false});
  final Post post;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    return Row(
      children: [
        GestureDetector(
          onTap: () => openAuthor(context, a),
          child: Avatar(
            url: a.avatar,
            size: small ? 32 : 44,
            network: small ? null : post.network,
            label: a.displayName,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => openAuthor(context, a),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        a.displayName,
                        style: context.tt.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '  ·  ${timeAgo(post.createdAt)}',
                      style: context.tt.bodySmall,
                    ),
                  ],
                ),
                Text(
                  '@${a.handle}',
                  style: context.tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        if (!small) NetworkPill(post.network, dense: true),
      ],
    );
  }
}

class _CommunityChip extends StatelessWidget {
  const _CommunityChip(this.c);
  final Community c;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: context.jc.r(30),
      onTap: () => openCommunity(context, c),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
        decoration: BoxDecoration(
          color: context.jc.cardHigh,
          borderRadius: context.jc.r(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(url: c.avatar, size: 20, label: c.displayTitle),
            const SizedBox(width: 6),
            Text(
              'c/${c.name.split('@').first}',
              style: context.tt.labelLarge?.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerStatefulWidget {
  const _Actions({required this.post});
  final Post post;

  @override
  ConsumerState<_Actions> createState() => _ActionsState();
}

class _ActionsState extends ConsumerState<_Actions> {
  bool _liked = false;
  bool _boosted = false;

  /// Faz a ação com a conta certa; sem conta, mostra o aviso que leva ao
  /// onboarding do fediverso. A interface muda na hora e volta atrás se o
  /// servidor recusar.
  Future<void> _act({
    required AccountAction kind,
    required bool current,
    required void Function(bool) set,
    required Future<void> Function(AccountsNotifier) action,
    required String done,
  }) async {
    if (current) return; // desfazer ainda não é suportado em todas as redes
    final messenger = ScaffoldMessenger.of(context);
    final account = await requireAccount(
      context,
      ref,
      action: kind,
      network: widget.post.network,
    );
    if (account == null || !mounted) return;
    setState(() => set(true));
    try {
      await action(ref.read(accountsProvider.notifier));
      messenger.showSnackBar(
        SnackBar(content: Text(done), duration: const Duration(seconds: 2)),
      );
    } catch (e) {
      setState(() => set(false));
      messenger.showSnackBar(SnackBar(content: Text('Não deu: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final jc = context.jc;
    final lemmy = p.network == Network.lemmy;
    final canBoost =
        !lemmy && p.network != Network.peertube && p.network != Network.loops;
    return Row(
      children: [
        Stat(
          Icons.chat_bubble_outline_rounded,
          p.replies > 0 ? compact(p.replies) : '',
          onTap: () => openPost(context, p),
          semanticLabel: p.replies > 0
              ? '${p.replies} respostas. Abrir post'
              : 'Responder',
        ),
        if (canBoost)
          Stat(
            Icons.repeat_rounded,
            compact(p.reposts + (_boosted ? 1 : 0))
                .replaceAll(RegExp(r'^0$'), ''),
            color: _boosted ? Jabu.leaf : null,
            onTap: () => _act(
              kind: AccountAction.boost,
              current: _boosted,
              set: (v) => _boosted = v,
              action: (n) => n.boost(p),
              done: 'Compartilhado ✓',
            ),
            semanticLabel: 'Compartilhar',
          ),
        if (p.views != null)
          Stat(
            Icons.visibility_outlined,
            compact(p.views),
            semanticLabel: '${compact(p.views)} visualizações',
          ),
        Stat(
          lemmy
              ? Icons.arrow_upward_rounded
              : (_liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded),
          compact(p.likes + (_liked ? 1 : 0)),
          color: _liked ? jc.hot : null,
          onTap: () => _act(
            kind: lemmy ? AccountAction.vote : AccountAction.like,
            current: _liked,
            set: (v) => _liked = v,
            action: (n) => n.like(p),
            done: lemmy ? 'Voto enviado ✓' : 'Curtido ✓',
          ),
          semanticLabel: lemmy ? 'Votar' : 'Curtir',
        ),
        const Spacer(),
        ModerationMenu(author: p.author, post: p),
        if (p.url != null)
          IconButton(
            tooltip: 'Abrir original',
            visualDensity: VisualDensity.compact,
            onPressed: () => openUrl(p.url!),
            icon: Icon(Icons.open_in_new_rounded, size: 18, color: jc.muted),
          ),
      ],
    );
  }
}
