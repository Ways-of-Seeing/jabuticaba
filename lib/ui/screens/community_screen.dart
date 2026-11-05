import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/directory.dart';
import '../../services/mastodon.dart';
import '../../state/loaders.dart';
import '../../state/settings.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/paged.dart';
import '../widgets/post_card.dart';
import '../widgets/rich_content.dart';

/// Página de um servidor, comunidade Lemmy, feed do Bluesky ou canal PeerTube.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key, required this.community});
  final Community community;

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  late Community _c = widget.community;

  @override
  void initState() {
    super.initState();
    if (_c.kind == CommunityKind.server) {
      MastodonApi.instanceInfo(_c.name)
          .then((info) {
            if (!mounted) return;
            setState(
              () => _c = Community(
                id: _c.id,
                kind: _c.kind,
                network: _c.network,
                name: _c.name,
                title: info.title ?? _c.title,
                description: (_c.description?.isNotEmpty ?? false)
                    ? _c.description
                    : info.description,
                banner: _c.banner ?? info.banner,
                blurhash: _c.blurhash ?? info.blurhash,
                members: _c.members,
                activeMembers: info.activeMembers ?? _c.activeMembers,
                url: _c.url,
                category: _c.category,
                instance: _c.instance,
                approvalRequired: info.approvalRequired,
              ),
            );
          })
          .catchError((_) {});
    }
  }

  String get _subtitle => switch (_c.kind) {
    CommunityKind.server => 'Servidor Mastodon',
    CommunityKind.group => 'Comunidade Lemmy',
    CommunityKind.feed =>
      'Feed do Bluesky${_c.instance != null ? ' · por @${_c.instance}' : ''}',
    CommunityKind.channel => 'Canal PeerTube',
    CommunityKind.hashtag => 'Hashtag',
    CommunityKind.person => 'Perfil',
    CommunityKind.podcast => 'Podcast',
  };

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final following = ref.watch(
      settingsProvider.select((s) => s.isFollowing(widget.community.key)),
    );
    final jc = context.jc;
    final hasBanner = c.banner?.isNotEmpty ?? false;

    final header = SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: context.jc.r(22),
                  child: SizedBox(
                    height: hasBanner ? 200 : 120,
                    width: double.infinity,
                    child: hasBanner
                        ? NetImage(c.banner, blurhash: c.blurhash)
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  context.jc.network(c.network),
                                  context.jc.brand,
                                  context.jc.hot,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.avatar != null) ...[
                      Avatar(
                        url: c.avatar,
                        size: 56,
                        square: true,
                        label: c.displayTitle,
                      ),
                      const SizedBox(width: 14),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.displayTitle,
                            style: context.tt.headlineMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(_subtitle, style: context.tt.bodySmall),
                        ],
                      ),
                    ),
                    FollowButton(
                      following: following,
                      dense: true,
                      onTap: () => ref
                          .read(settingsProvider.notifier)
                          .toggleFollow(widget.community),
                    ),
                  ],
                ),
              ),
              if (c.description?.isNotEmpty ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: RichContent(
                    html: c.description!.contains('<') ? c.description : null,
                    text: stripMarkdown(c.description),
                    maxLines: 5,
                    style: context.tt.bodyMedium?.copyWith(color: jc.muted),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    NetworkPill(c.network),
                    if (c.members != null && c.members! > 0)
                      _Fact(
                        Icons.people_alt_rounded,
                        '${compact(c.members)} ${c.kind == CommunityKind.feed ? 'curtidas' : 'membros'}',
                      ),
                    if (c.activeMembers != null)
                      _Fact(
                        Icons.bolt_rounded,
                        '${compact(c.activeMembers)} ativos',
                      ),
                    if (c.category != null)
                      _Fact(
                        Icons.sell_rounded,
                        ServerDirectory.categoryLabels[c.category] ??
                            c.category!,
                      ),
                    if (c.kind == CommunityKind.server && c.approvalRequired)
                      const _Fact(
                        Icons.how_to_reg_rounded,
                        'Cadastro com aprovação',
                      ),
                  ],
                ),
              ),
              if (c.kind == CommunityKind.server)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            openUrl('https://${c.name}/auth/sign_up'),
                        icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                        label: const Text('Criar conta aqui'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton(
                        onPressed: () => openUrl('https://${c.name}/about'),
                        child: const Text('Regras e sobre'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              const Divider(),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(),
      body: PagedView<Post>(
        loader: communityLoader(widget.community),
        keyOf: (p) => p.key,
        maxWidth: 680,
        header: [header],
        empty: const MessageView(
          emoji: '🔒',
          title: 'Conteúdo fechado para visitantes',
          message: 'Este espaço não mostra posts sem login. Você ainda pode segui-lo ou criar uma conta.',
        ),
        sliverBuilder: (context, items) =>
            postListSliver(items, (p) => PostCard(post: p)),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: context.jc.muted),
      const SizedBox(width: 4),
      Text(label, style: context.tt.labelMedium),
    ],
  );
}
