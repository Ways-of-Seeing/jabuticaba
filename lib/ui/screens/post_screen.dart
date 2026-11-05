import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/bluesky.dart';
import '../../services/lemmy.dart';
import '../../services/mastodon.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/paged.dart';
import '../widgets/post_card.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.post});
  final Post post;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  late final Future<List<Reply>> _replies = _load();

  Future<List<Reply>> _load() async {
    final p = widget.post;
    return switch (p.network) {
      Network.bluesky => BlueskyApi.replies(p.ref!),
      Network.lemmy => LemmyApi.comments(p.id, p.instance!),
      Network.mastodon when p.instance != null => MastodonApi.replies(
        p.id,
        p.instance!,
      ),
      _ => Future.value(const <Reply>[]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.network == Network.lemmy ? 'Discussão' : 'Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: NetworkPill(p.network),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: FutureBuilder<List<Reply>>(
            future: _replies,
            builder: (context, snap) {
              final replies = snap.data ?? const <Reply>[];
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: PostCard(post: p, expanded: true)),
                  const SliverToBoxAdapter(child: Divider()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
                      child: Text(
                        snap.connectionState == ConnectionState.done
                            ? (replies.isEmpty
                                  ? 'Ainda sem respostas'
                                  : '${replies.length} respostas')
                            : 'Respostas',
                        style: context.tt.titleMedium,
                      ),
                    ),
                  ),
                  if (snap.connectionState != ConnectionState.done)
                    const SliverToBoxAdapter(child: PostSkeletons(count: 2))
                  else if (snap.hasError)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Não foi possível carregar as respostas deste servidor.',
                          style: context.tt.bodySmall,
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: replies.length,
                      itemBuilder: (context, i) => PostCard(
                        post: replies[i].post,
                        depth: replies[i].depth + 1,
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
