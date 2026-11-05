import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';
import '../state/accounts.dart';
import '../state/demo.dart';
import '../state/settings.dart';
import 'screens/compose_sheet.dart';
import 'widgets/theme_picker.dart';
import 'demo_scenes.dart';
import 'nav.dart';
import 'screens/clips_screen.dart';
import 'screens/communities_screen.dart';
import 'screens/explore_screen.dart';
import 'screens/fio_screen.dart';
import 'screens/music_screen.dart';
import 'screens/podcasts_screen.dart';
import 'screens/photos_screen.dart';
import 'screens/you_screen.dart';
import 'theme.dart';
import 'widgets/audio.dart';
import 'widgets/basics.dart';

/// Aba visível, para que telas como Clipes pausem quando saem de vista.
class CurrentTab extends Notifier<int> {
  @override
  int build() => 0;
  void set(int i) => state = i;
}

final currentTabProvider = NotifierProvider<CurrentTab, int>(CurrentTab.new);

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon, {this.short});
  final String label;

  /// Rótulo da barra inferior, onde o espaço é curto.
  final String? short;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab('Explorar', Icons.explore_outlined, Icons.explore_rounded),
  _Tab('Fio', Icons.view_agenda_outlined, Icons.view_agenda_rounded),
  _Tab('Clipes', Icons.play_circle_outline_rounded, Icons.play_circle_rounded),
  _Tab('Fotos', Icons.photo_library_outlined, Icons.photo_library_rounded),
  _Tab('Música', Icons.album_outlined, Icons.album_rounded),
  _Tab('Podcasts', Icons.podcasts_outlined, Icons.podcasts_rounded),
  _Tab(
    'Comunidades',
    Icons.diversity_3_outlined,
    Icons.diversity_3_rounded,
    short: 'Grupos',
  ),
  _Tab('Você', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Estrutura principal: barra lateral no desktop/tablet, barra inferior no
/// celular. Cada aba tem seu próprio Navigator, então abrir um perfil não
/// esconde a navegação e cada aba lembra onde você estava.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.initialTab = 0});

  /// Aba aberta ao iniciar (usado pelo modo demonstração).
  final int initialTab;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late int _index = widget.initialTab;
  final _navKeys = List.generate(
    _tabs.length,
    (_) => GlobalKey<NavigatorState>(),
  );
  late final _built = <int>{widget.initialTab};

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != 0) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(currentTabProvider.notifier).set(widget.initialTab),
      );
    }
    if (demoMode) {
      // Dá um instante para o Navigator da aba existir antes de abrir a cena.
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _navKeys[_index].currentState?.overlay?.context;
        if (ctx != null && ctx.mounted) {
          runDemoScene(ctx, ref, onSelect: _select);
        }
      });
    }
  }

  void _select(int i) {
    if (i == _index) {
      // Tocar de novo na aba volta para a raiz dela.
      _navKeys[i].currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _index = i;
      _built.add(i);
    });
    ref.read(currentTabProvider.notifier).set(i);
  }

  /// Abre algo seguido dentro da aba Fio, sem perder o lugar no Explorar.
  void _openFollow(Community f) {
    setState(() {
      _index = 1;
      _built.add(1);
    });
    ref.read(currentTabProvider.notifier).set(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _navKeys[1].currentState?.overlay?.context;
      if (ctx == null) return;
      switch (f.kind) {
        case CommunityKind.hashtag:
          openTag(ctx, f.name);
        case CommunityKind.person:
          openHandle(ctx, f.name, f.network);
        default:
          openCommunity(ctx, f);
      }
    });
  }

  Widget _root(int i) => switch (i) {
    0 => ExploreScreen(onOpenTab: _select),
    1 => const FioScreen(),
    2 => const ClipsScreen(),
    3 => const PhotosScreen(),
    4 => const MusicScreen(),
    5 => const PodcastsScreen(),
    6 => const CommunitiesScreen(),
    _ => const YouScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final clips = _index == 2;

    final stack = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < _tabs.length; i++)
          // Só constrói a aba quando visitada pela primeira vez.
          !_built.contains(i)
              ? const SizedBox.shrink()
              : HeroControllerScope(
                  controller: MaterialApp.createMaterialHeroController(),
                  child: Navigator(
                    key: _navKeys[i],
                    onGenerateRoute: (_) =>
                        MaterialPageRoute(builder: (_) => _root(i)),
                  ),
                ),
      ],
    );

    final body = NavigatorPopHandler(
      onPopWithResult: (_) => _navKeys[_index].currentState?.maybePop(),
      child: stack,
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              index: _index,
              onSelect: _select,
              onOpenFollow: _openFollow,
            ),
            VerticalDivider(width: 1, color: context.jc.line),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: body),
                  const MiniPlayer(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      body: body,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(dark: clips),
          _BottomBar(index: _index, onSelect: _select, dark: clips),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.index,
    required this.onSelect,
    required this.onOpenFollow,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final ValueChanged<Community> onOpenFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(settingsProvider.select((s) => s.follows));
    final accounts = ref.watch(accountsProvider);
    final jc = context.jc;
    return Container(
      width: 252,
      color: jc.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 30, 16, 26),
              child: Wordmark(size: 22),
            ),
            for (var i = 0; i < _tabs.length; i++)
              _SideItem(
                tab: _tabs[i],
                selected: i == index,
                onTap: () => onSelect(i),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 0),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    gradient: jc.accent,
                    shape: jc.pill(),
                  ),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: jc.onAccent,
                    ),
                    onPressed: () => openComposer(context, ref),
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('Publicar'),
                  ),
                ),
              ),
            ),
            if (follows.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 26, 16, 8),
                child: Text('SEGUINDO', style: context.tt.labelSmall),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final f in follows.take(20))
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: context.jc.r(14),
                        ),
                        leading: Avatar(
                          url: f.avatar,
                          size: 26,
                          label: f.displayTitle,
                          square: true,
                        ),
                        title: Text(
                          f.displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => onOpenFollow(f),
                      ),
                  ],
                ),
              ),
            ] else
              const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
              child: Row(
                children: [
                  for (final a in accounts.take(4))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Tooltip(
                        message: '@${a.handle}',
                        child: Avatar(
                          url: a.avatar,
                          size: 28,
                          network: a.network,
                          label: a.name,
                        ),
                      ),
                    ),
                  if (accounts.isEmpty)
                    Expanded(
                      child: Text(
                        'Fediverso aberto · sem anúncios',
                        style: context.tt.bodySmall,
                      ),
                    )
                  else
                    const Spacer(),
                  IconButton(
                    tooltip:
                        'Visual: ${ref.watch(settingsProvider.select((s) => s.theme)).label}',
                    onPressed: () => showThemePicker(context),
                    icon: const Icon(Icons.palette_outlined),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideItem extends StatefulWidget {
  const _SideItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sel
                  ? (jc.solidSelection
                        ? jc.brand
                        : jc.brand.withValues(alpha: .14))
                  : (_hover ? jc.card : Colors.transparent),
              borderRadius: context.jc.r(16),
            ),
            child: Row(
              children: [
                Icon(
                  sel ? widget.tab.activeIcon : widget.tab.icon,
                  color: sel
                      ? (jc.solidSelection ? jc.onAccent : jc.brand)
                      : context.cs.onSurface,
                ),
                const SizedBox(width: 14),
                Text(
                  widget.tab.label,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                    color: sel
                        ? (jc.solidSelection ? jc.onAccent : jc.brand)
                        : context.cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// No celular cabem cinco abas; Fotos, Comunidades e Você ficam em "Mais".
const _mobileTabs = [0, 1, 2, 4, 5];
const _moreTabs = [3, 6, 7];

void showMoreMenu(BuildContext context, ValueChanged<int> onSelect) =>
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final i in _moreTabs)
                ListTile(
                  leading: Icon(_tabs[i].activeIcon),
                  title: Text(_tabs[i].label),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.pop(sheet);
                    onSelect(i);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.palette_rounded),
                title: const Text('Visual'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(sheet);
                  showThemePicker(context);
                },
              ),
            ],
          ),
        ),
      ),
    );

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.index,
    required this.onSelect,
    required this.dark,
  });
  final int index;
  final ValueChanged<int> onSelect;
  final bool dark;

  /// `-1` é o botão "Mais", aceso quando uma das abas dele está aberta.
  bool _sel(int i) => i == -1 ? _moreTabs.contains(index) : i == index;
  IconData _icon(int i) => i == -1
      ? (_sel(i) ? Icons.grid_view_rounded : Icons.grid_view_outlined)
      : (_sel(i) ? _tabs[i].activeIcon : _tabs[i].icon);
  String _label(int i) => i == -1 ? 'Mais' : (_tabs[i].short ?? _tabs[i].label);

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final fg = dark ? Colors.white : context.cs.onSurface;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: jc.blur ? 24 : 0,
          sigmaY: jc.blur ? 24 : 0,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? Colors.black.withValues(alpha: .55) : jc.glass,
            border: Border(
              top: BorderSide(color: dark ? Colors.white12 : jc.line),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  for (final i in [..._mobileTabs, -1])
                    Expanded(
                      child: InkResponse(
                        onTap: () => i == -1
                            ? showMoreMenu(context, onSelect)
                            : onSelect(i),
                        radius: 32,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _sel(i)
                                    ? (dark
                                          ? Colors.white24
                                          : context.cs.primary.withValues(
                                              alpha: .16,
                                            ))
                                    : Colors.transparent,
                                borderRadius: context.jc.r(20),
                              ),
                              child: Icon(
                                _icon(i),
                                size: 24,
                                color: _sel(i)
                                    ? (dark ? Colors.white : context.cs.primary)
                                    : fg.withValues(alpha: .75),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _label(i),
                              maxLines: 1,
                              overflow: TextOverflow.fade,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: _sel(i)
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: _sel(i)
                                    ? (dark ? Colors.white : context.cs.primary)
                                    : fg.withValues(alpha: .7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
