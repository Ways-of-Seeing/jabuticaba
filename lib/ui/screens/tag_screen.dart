import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/loaders.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/paged.dart';
import '../widgets/post_card.dart';

class TagScreen extends ConsumerWidget {
  const TagScreen({super.key, required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final community = Community(
      id: tag.toLowerCase(),
      kind: CommunityKind.hashtag,
      network: Network.mastodon,
      name: tag,
      title: '#$tag',
    );
    final following = ref.watch(
      settingsProvider.select((s) => s.isFollowing(community.key)),
    );

    return Scaffold(
      appBar: AppBar(),
      body: PagedView<Post>(
        loader: communityLoader(community),
        keyOf: (p) => p.key,
        maxWidth: 680,
        header: [
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  padding: const EdgeInsets.all(22),
                  decoration: context.jc.accentPanel(),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#$tag',
                              style: context.tt.displaySmall?.copyWith(
                                color: context.jc.onAccent,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Posts do Mastodon e vídeos do Loops com esta hashtag',
                              style: TextStyle(
                                color: context.jc.onAccent.withValues(
                                  alpha: .8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.jc.onAccent,
                          foregroundColor: context.jc.accent.colors.first,
                        ),
                        onPressed: () => ref
                            .read(settingsProvider.notifier)
                            .toggleFollow(community),
                        child: Text(following ? 'Seguindo' : 'Seguir'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        empty: MessageView(emoji: '🔎', title: 'Nada com #$tag por enquanto'),
        sliverBuilder: (context, items) =>
            postListSliver(items, (p) => PostCard(post: p)),
      ),
    );
  }
}
