import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/accounts.dart';
import '../../state/loaders.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/paged.dart';
import '../widgets/post_card.dart';
import 'compose_sheet.dart';

/// Aba "Fio": a linha do tempo em texto (Twitter/Threads/Bluesky) misturando redes.
class FioScreen extends ConsumerStatefulWidget {
  const FioScreen({super.key});

  @override
  ConsumerState<FioScreen> createState() => _FioScreenState();
}

class _FioScreenState extends ConsumerState<FioScreen> {
  late FioSource _source = ref.read(accountsProvider).any((a) => !a.pending)
      ? FioSource.home
      : FioSource.all;

  static const _icons = {
    FioSource.home: Icons.home_rounded,
    FioSource.all: Icons.auto_awesome_rounded,
    FioSource.following: Icons.favorite_rounded,
    FioSource.mastodon: Icons.forum_rounded,
    FioSource.bluesky: Icons.cloud_rounded,
    FioSource.threads: Icons.alternate_email_rounded,
    FioSource.lemmy: Icons.groups_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final followsKey = settings.follows.map((f) => f.key).join(',');
    final accounts = ref
        .watch(accountsProvider)
        .where((a) => !a.pending)
        .toList();
    final hasAccounts = accounts.isNotEmpty;
    final accountsKey = accounts.map((a) => a.id).join(',');
    // Se a última conta for desconectada, volta para "Para você".
    final source = _source == FioSource.home && !hasAccounts
        ? FioSource.all
        : _source;

    final chips = SliverPersistentHeader(
      pinned: true,
      delegate: _ChipsHeader(
        child: SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final s in FioSource.values.where(
                (s) => s != FioSource.home || hasAccounts,
              ))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    selected: s == source,
                    avatar: Icon(
                      _icons[s],
                      size: 16,
                      color: s == source
                          ? context.cs.primary
                          : context.jc.muted,
                    ),
                    label: Text(s.label),
                    onSelected: (_) => setState(() => _source = s),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.jc.headline('Fio')),
        toolbarHeight: 64,
        titleTextStyle: context.tt.headlineLarge?.copyWith(
          color: context.jc.onTitleBar,
        ),
      ),
      floatingActionButton: context.isWide
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 70),
              child: FloatingActionButton(
                tooltip: 'Publicar',
                backgroundColor: context.jc.brand,
                foregroundColor: context.jc.onAccent,
                shape: context.jc.bevel
                    ? const Win95Border()
                    : (context.jc.square
                          ? const RoundedRectangleBorder()
                          : null),
                onPressed: () => openComposer(context, ref),
                child: const Icon(Icons.edit_rounded),
              ),
            ),
      body: PagedView<Post>(
        key: ValueKey(
          '${source.name}|${source == FioSource.home ? accountsKey : ''}|${settings.interests.join(',')}|${source == FioSource.following ? followsKey : ''}',
        ),
        loader: source == FioSource.home
            ? ref.read(accountsProvider.notifier).homeLoader()
            : fioLoader(source, settings),
        keyOf: (p) => p.key,
        maxWidth: 680,
        header: [chips],
        empty: source == FioSource.following
            ? const MessageView(
                emoji: '🌱',
                title: 'Você ainda não segue nada',
                message: 'Toque em "Seguir" em perfis, hashtags, comunidades e feeds. Não precisa de conta — fica salvo aqui.',
              )
            : null,
        sliverBuilder: (context, items) =>
            postListSliver(items, (p) => PostCard(post: p)),
      ),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({required this.child});
  final Widget child;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: context.jc.canvas,
        border: overlapsContent || shrinkOffset > 0
            ? Border(bottom: BorderSide(color: context.jc.line))
            : null,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: child,
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipsHeader old) => true;
}
