import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/directory.dart';
import '../../state/explore.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';

/// Aba "Comunidades": onde as pessoas escolhem seus cantos do fediverso.
class CommunitiesScreen extends ConsumerStatefulWidget {
  const CommunitiesScreen({super.key});

  @override
  ConsumerState<CommunitiesScreen> createState() => _CommunitiesScreenState();
}

enum _Kind {
  groups('Comunidades', '🫂', 'Fóruns do Lemmy sobre todo tipo de assunto'),
  servers('Servidores', '🏡', 'Escolha onde criar sua conta no Mastodon'),
  feeds('Feeds', '🦋', 'Feeds temáticos do Bluesky'),
  channels('Canais', '📺', 'Canais de vídeo do PeerTube');

  const _Kind(this.label, this.emoji, this.blurb);
  final String label;
  final String emoji;
  final String blurb;
}

class _CommunitiesScreenState extends ConsumerState<CommunitiesScreen> {
  _Kind _kind = _Kind.groups;
  String? _category;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final channelQuery = settings.chosen.isEmpty
        ? 'music'
        : settings.chosen.first.query;
    final AsyncValue<List<Community>> data = switch (_kind) {
      _Kind.groups => ref.watch(lemmyCommunitiesProvider),
      _Kind.servers => ref.watch(serversProvider(_category)),
      _Kind.feeds => ref.watch(bskyFeedsProvider),
      _Kind.channels => ref.watch(peertubeChannelsProvider(channelQuery)),
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(context.jc.headline('Comunidades')),
        toolbarHeight: 64,
        titleTextStyle: context.tt.headlineLarge?.copyWith(
          color: context.jc.onTitleBar,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<_Kind>(
                  segments: [
                    for (final k in _Kind.values)
                      ButtonSegment(
                        value: k,
                        label: Text('${k.emoji}  ${k.label}'),
                      ),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _kind = s.first),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(
                _kind.blurb,
                style: context.tt.bodyMedium?.copyWith(color: context.jc.muted),
              ),
            ),
          ),
          if (_kind == _Kind.servers)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: _category == null,
                        label: const Text('Todos'),
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    for (final e in ServerDirectory.categoryLabels.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _category == e.key,
                          label: Text(e.value),
                          onSelected: (_) => setState(() => _category = e.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ...data.when(
            loading: () => [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _grid(context, 8, (_) => const Skeleton(radius: 22)),
              ),
            ],
            error: (e, _) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: MessageView.error(
                  e,
                  () => ref.invalidate(lemmyCommunitiesProvider),
                ),
              ),
            ],
            data: (items) => [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: _grid(
                  context,
                  items.length,
                  (i) => CommunityCard(community: items[i], width: null),
                ),
              ),
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, int count, Widget Function(int) builder) =>
      SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 320,
          mainAxisExtent: 250,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: count,
        itemBuilder: (context, i) => builder(i),
      );
}
