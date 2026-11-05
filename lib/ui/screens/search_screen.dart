import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/explore.dart';
import '../../state/interests.dart';
import '../nav.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/cards.dart';

/// Busca única em Mastodon, Bluesky, Lemmy e PeerTube.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  /// Busca já preenchida ao abrir.
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) {
      _ctrl.text = q;
      _q = q;
    }
  }

  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 450),
      () => setState(() => _q = v.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Hero(
            tag: 'search',
            child: Material(
              color: Colors.transparent,
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (v) => setState(() => _q = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Pessoas, hashtags, comunidades, vídeos…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _q = '');
                          },
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _q.isEmpty ? _suggestions(context) : _results(context),
    );
  }

  Widget _suggestions(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('Sugestões', style: context.tt.titleMedium),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final i in interests)
            ActionChip(
              avatar: Text(i.emoji),
              label: Text(i.label),
              onPressed: () {
                _ctrl.text = i.query;
                setState(() => _q = i.query);
              },
            ),
        ],
      ),
    ],
  );

  Widget _results(BuildContext context) {
    final res = ref.watch(searchProvider(_q));
    return res.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) =>
          MessageView.error(e, () => ref.invalidate(searchProvider(_q))),
      data: (r) {
        if (r.isEmpty) {
          return MessageView(emoji: '🔍', title: 'Nada encontrado para "$_q"');
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            if (r.tags.isNotEmpty) ...[
              const SectionHeader('Hashtags', emoji: '#️⃣'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in r.tags.take(12))
                      ActionChip(
                        label: Text('#${t.name}'),
                        onPressed: () => openTag(context, t.name),
                      ),
                  ],
                ),
              ),
            ],
            if (r.people.isNotEmpty) ...[
              const SectionHeader('Pessoas', emoji: '🙋'),
              for (final a in r.people.take(12))
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  leading: Avatar(
                    url: a.avatar,
                    network: a.network,
                    label: a.displayName,
                  ),
                  title: Text(
                    a.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '@${a.handle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: NetworkPill(a.network, dense: true),
                  onTap: () => openAuthor(context, a),
                ),
            ],
            if (r.communities.isNotEmpty) ...[
              const SectionHeader('Comunidades e feeds', emoji: '🫂'),
              Carousel(
                height: 250,
                itemCount: r.communities.length,
                itemBuilder: (context, i) =>
                    CommunityCard(community: r.communities[i]),
              ),
            ],
            if (r.videos.isNotEmpty) ...[
              const SectionHeader('Vídeos', emoji: '📺'),
              Carousel(
                height: 250,
                itemCount: r.videos.length,
                itemBuilder: (context, i) => VideoCard(post: r.videos[i]),
              ),
            ],
          ],
        );
      },
    );
  }
}
