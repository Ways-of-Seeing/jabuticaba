import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/settings.dart';
import '../theme.dart';

/// Grade de temas; cada miniatura é desenhada com o próprio tema.
class ThemePicker extends ConsumerWidget {
  const ThemePicker({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(settingsProvider.select((s) => s.theme));
    return LayoutBuilder(
      builder: (context, c) {
        final cols = (c.maxWidth / (compact ? 150 : 170)).floor().clamp(2, 4);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final id in JabuThemeId.values)
              SizedBox(
                width: w,
                child: _ThemeTile(
                  id: id,
                  selected: id == current,
                  onTap: () => ref.read(settingsProvider.notifier).setTheme(id),
                ),
              ),
          ],
        );
      },
    );
  }
}

Future<void> showThemePicker(BuildContext context) => showModalBottomSheet(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 760),
  builder: (context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.jc.headline('Visual'), style: context.tt.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Escolha a cara do jabuticaba. Muda na hora.',
            style: context.tt.bodyMedium?.copyWith(color: context.jc.muted),
          ),
          const SizedBox(height: 18),
          const ThemePicker(),
        ],
      ),
    ),
  ),
);

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.id,
    required this.selected,
    required this.onTap,
  });
  final JabuThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outer = context.jc;
    final preview = id == JabuThemeId.system
        ? Row(
            children: [
              Expanded(
                child: _Mini(style: JabuStyle.polpa, label: 'Aa'),
              ),
              Expanded(
                child: _Mini(style: JabuStyle.jabuticaba, label: 'Aa'),
              ),
            ],
          )
        : _Mini(style: JabuStyle.of(id), label: 'Aa jabuticaba');
    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${id.label}',
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  borderRadius: outer.r(18),
                  border: Border.all(
                    color: selected ? outer.brand : outer.line,
                    width: selected ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: outer.r(14),
                  child: SizedBox(
                    height: 108,
                    width: double.infinity,
                    child: preview,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      id.label,
                      style: context.tt.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: outer.brand,
                    ),
                ],
              ),
              Text(
                id.blurb,
                style: context.tt.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniatura de tela: barra, um cartão com título e um botão.
class _Mini extends StatelessWidget {
  const _Mini({required this.style, required this.label});
  final JabuStyle style;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = style;
    final title = TextStyle(
      fontFamily: s.displayFont,
      fontWeight: s.displayWeight,
      fontSize: s.displayFont == 'VT323' ? 21 : 16,
      color: s.ink,
      shadows: s.glow,
      height: 1,
    );
    return Container(
      color: s.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 16,
            color: s.titleBar ?? s.card,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: (s.onTitleBar ?? s.muted).withValues(alpha: .8),
                      shape: s.square ? BoxShape.rectangle : BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: s.panel(base: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.headline(label),
                      style: title,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 4,
                      width: 70,
                      color: s.muted.withValues(alpha: .5),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 4,
                      width: 50,
                      color: s.muted.withValues(alpha: .35),
                    ),
                    const Spacer(),
                    Container(
                      height: 16,
                      width: 52,
                      decoration: ShapeDecoration(
                        gradient: s.accent,
                        shape: s.pill(),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Seguir',
                        style: TextStyle(
                          fontFamily: s.bodyFont,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: s.onAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
