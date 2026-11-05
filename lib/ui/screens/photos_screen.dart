import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/loaders.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/media.dart';
import '../widgets/paged.dart';

/// Aba "Fotos": grade estilo Instagram/Pinterest com Pixelfed, Mastodon e Bluesky.
class PhotosScreen extends ConsumerStatefulWidget {
  const PhotosScreen({super.key});

  @override
  ConsumerState<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends ConsumerState<PhotosScreen> {
  String? _tag;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tags = [
      'photography',
      'nature',
      'art',
      'architecture',
      'streetphotography',
      'cats',
      'food',
      'illustration',
    ];
    final loader = _tag == null
        ? photosLoader(settings)
        : mix({
            'masto': mastodonTag(_tag!, media: true),
            'loops': loopsTag(_tag!),
          }, where: (p) => p.hasImage && !p.sensitive);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.jc.headline('Fotos')),
        toolbarHeight: 64,
        titleTextStyle: context.tt.headlineLarge?.copyWith(
          color: context.jc.onTitleBar,
        ),
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final columns = (c.maxWidth / 260).floor().clamp(2, 6);
          return PagedView<Post>(
            key: ValueKey('photos:$_tag:${settings.interests.join(',')}'),
            loader: loader,
            keyOf: (p) => p.key,
            skeleton: _GridSkeleton(columns: columns),
            header: [
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
                          selected: _tag == null,
                          label: const Text('✨ Em alta'),
                          onSelected: (_) => setState(() => _tag = null),
                        ),
                      ),
                      for (final t in tags)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: _tag == t,
                            label: Text('#$t'),
                            onSelected: (_) => setState(() => _tag = t),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 6)),
            ],
            sliverBuilder: (context, items) =>
                MasonrySliver(items: items, columns: columns),
          );
        },
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton({required this.columns});
  final int columns;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns; c++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  children: [
                    for (var i = 0; i < 3; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _Box(height: 160.0 + ((c + i) % 3) * 70),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: context.jc.card,
      borderRadius: context.jc.r(16),
    ),
  );
}
