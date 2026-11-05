import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../state/loaders.dart';
import '../theme.dart';
import 'basics.dart';

/// Lista com paginação infinita, "puxar para atualizar" e estados de vazio/erro.
///
/// O conteúdo é desenhado por [sliverBuilder] (lista, grade, masonry…), para que
/// todos os fios do app compartilhem a mesma lógica de carregamento. Para trocar
/// de fonte, mude a `key` do widget.
class PagedView<T> extends StatefulWidget {
  const PagedView({
    super.key,
    required this.loader,
    required this.keyOf,
    required this.sliverBuilder,
    this.header = const [],
    this.empty,
    this.maxWidth,
    this.skeleton,
    this.onItems,
    this.controller,
  });

  final Loader<T> loader;
  final String Function(T) keyOf;
  final Widget Function(BuildContext context, List<T> items) sliverBuilder;
  final List<Widget> header;
  final Widget? empty;
  final double? maxWidth;
  final Widget? skeleton;
  final void Function(List<T> items)? onItems;
  final ScrollController? controller;

  @override
  State<PagedView<T>> createState() => PagedViewState<T>();
}

class PagedViewState<T> extends State<PagedView<T>> {
  final _items = <T>[];
  final _seen = <String>{};
  String? _cursor;
  bool _done = false;
  bool _loading = false;
  Object? _error;
  int _generation = 0;
  late final ScrollController _scroll = widget.controller ?? ScrollController();

  List<T> get items => _items;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    if (widget.controller == null) _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 900) _load();
  }

  Future<void> refresh() async {
    _generation++;
    setState(() {
      _items.clear();
      _seen.clear();
      _cursor = null;
      _done = false;
      _loading = false;
      _error = null;
    });
    await _load();
  }

  Future<void> _load() async {
    if (_loading || _done) return;
    final gen = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var page = await widget.loader(_cursor);
      // Algumas fontes devolvem páginas só com repetidos; avançamos algumas vezes.
      var tries = 0;
      while (gen == _generation &&
          page.cursor != null &&
          page.items.every((i) => _seen.contains(widget.keyOf(i))) &&
          tries++ < 2) {
        page = await widget.loader(page.cursor);
      }
      if (!mounted || gen != _generation) return;
      setState(() {
        for (final item in page.items) {
          if (_seen.add(widget.keyOf(item))) _items.add(item);
        }
        _cursor = page.cursor;
        _done = page.cursor == null;
        _loading = false;
      });
      widget.onItems?.call(_items);
      // Se a primeira página não encheu a tela, carrega mais.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            _scroll.hasClients &&
            _scroll.position.maxScrollExtent < 400) {
          _load();
        }
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Widget _constrain(Widget sliver) {
    final w = widget.maxWidth;
    if (w == null) return sliver;
    return SliverLayoutBuilder(
      builder: (context, c) {
        final pad = ((c.crossAxisExtent - w) / 2).clamp(0.0, double.infinity);
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: sliver,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialLoading = _items.isEmpty && _loading;
    return RefreshIndicator(
      onRefresh: refresh,
      color: context.cs.primary,
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          ...widget.header,
          if (initialLoading)
            _constrain(
              SliverToBoxAdapter(
                child: widget.skeleton ?? const PostSkeletons(),
              ),
            )
          else if (_items.isEmpty && _error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: MessageView.error(_error!, refresh),
            )
          else if (_items.isEmpty && _done)
            SliverFillRemaining(
              hasScrollBody: false,
              child:
                  widget.empty ??
                  const MessageView(
                    emoji: '🌱',
                    title: 'Nada por aqui ainda',
                    message: 'Volte daqui a pouco.',
                  ),
            )
          else
            _constrain(widget.sliverBuilder(context, _items)),
          if (_items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: _loading
                      ? const SizedBox.square(
                          dimension: 26,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        )
                      : _error != null
                      ? TextButton(
                          onPressed: _load,
                          child: const Text('Tentar carregar mais'),
                        )
                      : _done
                      ? Text(
                          'Você chegou ao fim 🫐',
                          style: context.tt.bodySmall,
                        )
                      : const SizedBox(height: 26),
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 90)),
        ],
      ),
    );
  }
}

/// Lista de posts separada por linhas finas.
Widget postListSliver(List<Post> items, Widget Function(Post) builder) =>
    SliverList.separated(
      itemCount: items.length,
      itemBuilder: (context, i) => builder(items[i]),
      separatorBuilder: (_, _) => const Divider(indent: 16, endIndent: 16),
    );

class PostSkeletons extends StatelessWidget {
  const PostSkeletons({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Skeleton(width: 44, height: 44, radius: 22),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 140, height: 14),
                        SizedBox(height: 6),
                        Skeleton(width: 90, height: 11),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Skeleton(height: 14),
                const SizedBox(height: 8),
                const Skeleton(width: 240, height: 14),
                if (i.isEven) ...[
                  const SizedBox(height: 12),
                  const Skeleton(height: 200, radius: 18),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
