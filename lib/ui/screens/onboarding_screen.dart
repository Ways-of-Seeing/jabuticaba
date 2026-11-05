import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../state/demo.dart';
import '../../state/interests.dart';
import '../../state/settings.dart';
import '../theme.dart';
import '../widgets/basics.dart';
import '../widgets/theme_picker.dart';
import 'fediverse_screen.dart';

/// Boas-vindas em quatro passos: o que é, do que você gosta, que cara o app
/// deve ter e como você quer entrar no fediverso.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _steps = 4;
  late final _page = PageController(initialPage: _step);
  final _chosen = <String>{};
  int _step = (int.tryParse(demoParam('passo') ?? '') ?? 0).clamp(0, 3);

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _goTo(int i) => _page.animateToPage(
    i,
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

  void _done() => ref.read(settingsProvider.notifier).finishOnboarding(_chosen);

  Future<void> _enter(FediStart start) async {
    await openFediverse(context, start: start);
    // Conectando, criando ou desistindo, a pessoa segue para o app.
    if (mounted) _done();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final canNext = _step != 1 || _chosen.isNotEmpty;
    return Scaffold(
      body: Stack(
        children: [
          if (!jc.retro) const Positioned.fill(child: _Glow()),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 660),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView(
                        controller: _page,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (i) => setState(() => _step = i),
                        children: [
                          const _Welcome(),
                          _Interests(
                            chosen: _chosen,
                            onChanged: () => setState(() {}),
                          ),
                          const _Visual(),
                          _Enter(
                            onConnect: () => _enter(FediStart.connect),
                            onCreate: () => _enter(FediStart.create),
                            onExplore: _done,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Row(
                        children: [
                          for (var i = 0; i < _steps; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(right: 6),
                              width: i == _step ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _step ? jc.brand : jc.line,
                                borderRadius: jc.r(8),
                              ),
                            ),
                          const Spacer(),
                          if (_step > 0)
                            TextButton(
                              onPressed: () => _goTo(_step - 1),
                              child: const Text('Voltar'),
                            ),
                          if (_step == 1 && _chosen.isEmpty)
                            TextButton(
                              onPressed: () => _goTo(2),
                              child: const Text('Pular'),
                            ),
                          const SizedBox(width: 8),
                          if (_step < _steps - 1)
                            DecoratedBox(
                              decoration: ShapeDecoration(
                                gradient: canNext ? jc.accent : null,
                                color: canNext ? null : jc.cardHigh,
                                shape: jc.pill(),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: canNext
                                      ? jc.onAccent
                                      : jc.muted,
                                ),
                                onPressed: canNext
                                    ? () => _goTo(_step + 1)
                                    : null,
                                child: Text(switch (_step) {
                                  0 => 'Começar',
                                  1 =>
                                    _chosen.isEmpty
                                        ? 'Escolha ao menos 1'
                                        : 'Continuar (${_chosen.length})',
                                  _ => 'Continuar',
                                }),
                              ),
                            ),
                        ],
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

class _Glow extends StatelessWidget {
  const _Glow();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(-.6, -.9),
        radius: 1.3,
        colors: [context.jc.brand.withValues(alpha: .22), Colors.transparent],
      ),
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    const nets = [
      Network.mastodon,
      Network.bluesky,
      Network.pixelfed,
      Network.loops,
      Network.peertube,
      Network.lemmy,
      Network.funkwhale,
      Network.castopod,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: JabuLogo(size: 104),
        ),
        const SizedBox(height: 22),
        Text(
          'Todas as redes abertas.\nUm lugar só.',
          style: context.tt.displayMedium,
        ),
        const SizedBox(height: 16),
        Text(
          'O jabuticaba é uma janela para o fediverso: vídeos curtos, fotos, conversas e comunidades '
          'de redes independentes — sem dono, sem anúncios no meio, sem precisar de conta pra começar.',
          style: context.tt.bodyLarge?.copyWith(
            color: context.jc.muted,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final n in nets) NetworkPill(n)],
        ),
        const SizedBox(height: 30),
        const _Bullet(
          Icons.explore_rounded,
          'Explore sem login',
          'Veja o que está em alta em cada rede.',
        ),
        const _Bullet(
          Icons.bookmark_added_rounded,
          'Siga do seu jeito',
          'Perfis, hashtags e comunidades ficam salvos no aparelho.',
        ),
        const _Bullet(
          Icons.hub_rounded,
          'Todas as contas juntas',
          'Conecte Mastodon, Bluesky, Pixelfed e Lemmy — ou crie sua primeira conta aqui.',
        ),
      ],
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: context.jc.brand.withValues(alpha: .14),
            borderRadius: context.jc.r(14),
          ),
          child: Icon(icon, color: context.jc.brand),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.tt.titleMedium),
              Text(
                text,
                style: context.tt.bodyMedium?.copyWith(color: context.jc.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Interests extends StatelessWidget {
  const _Interests({required this.chosen, required this.onChanged});
  final Set<String> chosen;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Text(
          context.jc.headline('Do que você gosta?'),
          style: context.tt.displaySmall,
        ),
        const SizedBox(height: 10),
        Text(
          'Vamos montar seu explorar com isso. Dá pra mudar quando quiser.',
          style: context.tt.bodyLarge?.copyWith(color: context.jc.muted),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final i in interests)
              InterestChip(
                interest: i,
                selected: chosen.contains(i.id),
                onTap: () {
                  chosen.contains(i.id)
                      ? chosen.remove(i.id)
                      : chosen.add(i.id);
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Visual extends StatelessWidget {
  const _Visual();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
    children: [
      Text(
        context.jc.headline('Que cara ele deve ter?'),
        style: context.tt.displaySmall,
      ),
      const SizedBox(height: 10),
      Text(
        'Toque para experimentar — o app inteiro muda na hora.',
        style: context.tt.bodyLarge?.copyWith(color: context.jc.muted),
      ),
      const SizedBox(height: 26),
      const ThemePicker(compact: true),
    ],
  );
}

class _Enter extends StatelessWidget {
  const _Enter({
    required this.onConnect,
    required this.onCreate,
    required this.onExplore,
  });
  final VoidCallback onConnect;
  final VoidCallback onCreate;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    Widget option(
      IconData icon,
      String title,
      String text,
      VoidCallback onTap, {
      bool primary = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: jc.r(22),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: primary ? jc.accentPanel() : jc.panel(),
            child: Row(
              children: [
                Icon(icon, size: 28, color: primary ? jc.onAccent : jc.brand),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.tt.titleMedium?.copyWith(
                          color: primary ? jc.onAccent : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        text,
                        style: context.tt.bodyMedium?.copyWith(
                          color: primary
                              ? jc.onAccent.withValues(alpha: .85)
                              : jc.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: primary ? jc.onAccent : jc.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      children: [
        Text(
          jc.headline('Você já está no fediverso?'),
          style: context.tt.displaySmall,
        ),
        const SizedBox(height: 10),
        Text(
          'Com uma conta você curte, comenta, segue e publica — em várias redes ao mesmo tempo. Sem conta, você explora tudo do mesmo jeito.',
          style: context.tt.bodyLarge?.copyWith(color: jc.muted),
        ),
        const SizedBox(height: 26),
        option(
          Icons.auto_awesome_rounded,
          'Quero criar minha conta',
          'A gente sugere um servidor e cria junto, em português.',
          onCreate,
          primary: true,
        ),
        option(
          Icons.link_rounded,
          'Já tenho conta',
          'Mastodon, Pixelfed, Bluesky, Lemmy…',
          onConnect,
        ),
        option(
          Icons.explore_rounded,
          'Só quero explorar',
          'Dá pra conectar depois, na aba Você.',
          onExplore,
        ),
      ],
    );
  }
}

class InterestChip extends StatelessWidget {
  const InterestChip({
    super.key,
    required this.interest,
    required this.selected,
    required this.onTap,
  });
  final Interest interest;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final shape = jc.pill(side: selected ? null : jc.line);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: ShapeDecoration(
        gradient: selected ? jc.accent : null,
        color: selected ? null : jc.card,
        shape: jc.bevel ? Win95Border(sunken: selected) : shape,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(interest.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  interest.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15 * jc.sizeScale,
                    color: selected ? jc.onAccent : context.cs.onSurface,
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
