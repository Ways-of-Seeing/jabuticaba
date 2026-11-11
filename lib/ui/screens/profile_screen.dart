import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../models/models.dart';
import '../../services/bluesky.dart';
import '../../services/mastodon.dart';
import '../../state/accounts.dart';
import '../../state/loaders.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/media.dart';
import '../widgets/moderation_menu.dart';
import '../widgets/paged.dart';
import '../widgets/post_card.dart';
import '../widgets/rich_content.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.author});
  final Author author;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late Author _author = widget.author;
  bool _media = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  /// Completa os dados do perfil (bio, capa, contadores) quando possível.
  Future<void> _hydrate() async {
    try {
      final a = widget.author;
      final full = switch (a.network) {
        Network.bluesky => await BlueskyApi.profile(a.handle),
        Network.mastodon ||
        Network.pixelfed => (await MastodonApi.lookup(a.handle)).$1,
        _ => null,
      };
      if (full != null && mounted) setState(() => _author = full);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final a = _author;
    final person = Community(
      id: a.handle,
      kind: CommunityKind.person,
      network: a.network,
      name: a.handle,
      title: a.displayName,
      avatar: a.avatar,
    );
    final following = ref.watch(
      settingsProvider.select((s) => s.isFollowing(person.key)),
    );
    final jc = context.jc;

    final header = SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 210,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  bottom: 46,
                  child:
                      a.banner != null &&
                          a.banner!.isNotEmpty &&
                          !a.banner!.contains('missing')
                      ? NetImage(a.banner)
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                context.jc
                                    .network(a.network)
                                    .withValues(alpha: .7),
                                context.jc.brand,
                              ],
                            ),
                          ),
                        ),
                ),
                Positioned(
                  left: 20,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: jc.canvas,
                      shape: BoxShape.circle,
                    ),
                    child: Avatar(
                      url: a.avatar,
                      size: 92,
                      label: a.displayName,
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 0,
                  child: FollowButton(
                    following: following,
                    onTap: () async {
                      ref.read(settingsProvider.notifier).toggleFollow(person);
                      if (following) return;
                      final messenger = ScaffoldMessenger.of(context);
                      final account = ref
                          .read(accountsProvider.notifier)
                          .forNetwork(a.network);
                      if (account == null) return;
                      try {
                        await ref.read(accountsProvider.notifier).follow(a);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Seguindo também com @${account.handle} ✓',
                            ),
                          ),
                        );
                      } catch (e) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Salvo aqui, mas o servidor recusou: $e',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a.displayName, style: context.tt.headlineMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '@${a.handle}',
                        style: context.tt.bodyMedium?.copyWith(color: jc.muted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    NetworkPill(a.network, dense: true),
                  ],
                ),
                if (a.bio?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 12),
                  RichContent(
                    html: a.network == Network.bluesky ? null : a.bio,
                    text: a.bio!,
                    network: a.network,
                    style: context.tt.bodyMedium,
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  children: [
                    if (a.posts != null) _Count(a.posts!, 'posts'),
                    if (a.followers != null) _Count(a.followers!, 'seguidores'),
                    if (a.following != null) _Count(a.following!, 'seguindo'),
                  ],
                ),
                const SizedBox(height: 16),
                if (a.network != Network.loops && a.network != Network.peertube)
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Posts'),
                        icon: Icon(Icons.notes_rounded),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Mídia'),
                        icon: Icon(Icons.grid_view_rounded),
                      ),
                    ],
                    selected: {_media},
                    onSelectionChanged: (s) => setState(() => _media = s.first),
                    showSelectedIcon: false,
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          a.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ModerationMenu(author: a),
          const SizedBox(width: 4),
        ],
      ),
      body: PagedView<Post>(
        key: ValueKey('${a.handle}:$_media'),
        loader: authorLoader(widget.author, media: _media),
        keyOf: (p) => p.key,
        maxWidth: 720,
        header: [header],
        empty: const MessageView(
          emoji: '🫥',
          title: 'Nenhum post público',
          message: 'Este perfil ainda não publicou nada visível por aqui.',
        ),
        sliverBuilder: (context, items) {
          if (_media || a.network == Network.loops) {
            final width = MediaQuery.sizeOf(context).width.clamp(0, 720);
            return MasonrySliver(
              items: items.where((p) => p.media.isNotEmpty).toList(),
              columns: width > 500 ? 3 : 2,
            );
          }
          return postListSliver(items, (p) => PostCard(post: p));
        },
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count(this.n, this.label);
  final int n;
  final String label;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: compact(n), style: context.tt.titleMedium),
        TextSpan(
          text: ' $label',
          style: context.tt.bodyMedium?.copyWith(color: context.jc.muted),
        ),
      ],
    ),
  );
}
