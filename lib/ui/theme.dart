import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';

/// Temas disponíveis. "Sistema" alterna entre Jabuticaba e Polpa seguindo o
/// modo claro/escuro do aparelho.
enum JabuThemeId {
  system('Sistema', 'Segue o claro/escuro do aparelho'),
  jabuticaba('Jabuticaba', 'Escuro, roxo e brilhante'),
  polpa('Polpa', 'Claro e macio'),
  paperwhite('Paperwhite', 'Papel e tinta, como um Kindle'),
  win95('Windows 95', 'Cinza, relevo e barra azul'),
  ascii('ASCII', 'Texto puro, monoespaçado'),
  matrix('Matrix', 'Verde fósforo sobre preto'),
  contraste('Alto contraste', 'Máxima legibilidade');

  const JabuThemeId(this.label, this.blurb);
  final String label;
  final String blurb;
}

/// Constantes da marca (cores da fruta). Para cores que mudam com o tema,
/// use `context.jc`.
abstract final class Jabu {
  static const plum = Color(0xFF7B2D9E);
  static const grape = Color(0xFF9B4DCA);
  static const magenta = Color(0xFFE0459B);
  static const leaf = Color(0xFF5FBF7A);
  static const pulp = Color(0xFFFBF6FA);

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF8E3BB8), Color(0xFFE0459B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color brandNetwork(Network n) => switch (n) {
    Network.mastodon => const Color(0xFF6364FF),
    Network.bluesky => const Color(0xFF1185FE),
    Network.pixelfed => const Color(0xFFF0447A),
    Network.peertube => const Color(0xFFF1680D),
    Network.loops => const Color(0xFF00C2A8),
    Network.funkwhale => const Color(0xFF009FE3),
    Network.castopod => const Color(0xFF009486),
    Network.lemmy => const Color(0xFF14B88A),
  };

  static IconData networkIcon(Network n) => switch (n) {
    Network.mastodon => Icons.forum_rounded,
    Network.bluesky => Icons.cloud_rounded,
    Network.pixelfed => Icons.photo_camera_rounded,
    Network.peertube => Icons.smart_display_rounded,
    Network.loops => Icons.all_inclusive_rounded,
    Network.funkwhale => Icons.album_rounded,
    Network.castopod => Icons.podcasts_rounded,
    Network.lemmy => Icons.groups_rounded,
  };
}

/// Matriz de cor para deixar uma imagem em tons de cinza.
const _grayscale = ColorFilter.matrix([
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Cinza com contraste alto (tinta de impressora).
const _inked = ColorFilter.matrix([
  0.33, 0.85, 0.10, 0, -40, //
  0.33, 0.85, 0.10, 0, -40, //
  0.33, 0.85, 0.10, 0, -40, //
  0, 0, 0, 1, 0,
]);

/// Luminância convertida em verde fósforo.
const _phosphor = ColorFilter.matrix([
  0, 0, 0, 0, 0, //
  0.30, 0.75, 0.15, 0, 10, //
  0.05, 0.12, 0.03, 0, 0, //
  0, 0, 0, 1, 0,
]);

/// Tudo que define a cara de um tema além do ColorScheme do Material.
class JabuStyle extends ThemeExtension<JabuStyle> {
  const JabuStyle({
    required this.id,
    required this.brightness,
    required this.canvas,
    required this.card,
    required this.cardHigh,
    required this.line,
    required this.muted,
    required this.ink,
    required this.brand,
    required this.hot,
    required this.accent,
    required this.onAccent,
    required this.glass,
    this.radius = 22,
    this.displayFont = 'Bricolage',
    this.bodyFont = 'Jakarta',
    this.displayWeight = FontWeight.w800,
    this.bevel = false,
    this.monoNetworks = false,
    this.imageFilter,
    this.glow,
    this.titleBar,
    this.onTitleBar,
    this.solidSelection = false,
    this.blur = true,
    this.borderWidth = 1,
    this.sizeScale = 1,
  });

  final JabuThemeId id;
  final Brightness brightness;
  final Color canvas;
  final Color card;
  final Color cardHigh;
  final Color line;
  final Color muted;
  final Color ink;

  /// Cor principal do tema (botões, seleção, links).
  final Color brand;

  /// Cor de destaque para curtidas e alertas.
  final Color hot;

  /// Fundo dos elementos de destaque (botão Seguir, cabeçalhos de hashtag…).
  final Gradient accent;
  final Color onAccent;
  final Color glass;
  final double radius;
  final String displayFont;
  final String bodyFont;
  final FontWeight displayWeight;

  /// Relevo 3D do Windows 95 em vez de bordas planas.
  final bool bevel;

  /// Temas monocromáticos não usam as cores de cada rede.
  final bool monoNetworks;
  final ColorFilter? imageFilter;
  final List<Shadow>? glow;

  /// Cor da barra de título (AppBar) quando diferente do fundo.
  final Color? titleBar;
  final Color? onTitleBar;

  /// Item selecionado preenchido (Win95, contraste) em vez de tingido.
  final bool solidSelection;

  /// Desfoque de vidro nas barras (desligado em temas retrô).
  final bool blur;
  final double borderWidth;

  /// Fontes de pixel/terminal parecem menores; compensamos o tamanho.
  final double sizeScale;

  bool get dark => brightness == Brightness.dark;
  bool get square => radius == 0;
  bool get retro =>
      id == JabuThemeId.win95 ||
      id == JabuThemeId.ascii ||
      id == JabuThemeId.matrix;
  double get radiusSm => radius == 0 ? 0 : (radius * .64).roundToDouble();

  /// Raio proporcional ao tema: `r(18)` vira 0 em temas quadrados.
  BorderRadius r(double base) => radius == 0
      ? BorderRadius.zero
      : BorderRadius.circular((base * radius / 22).clamp(0, base));

  Color network(Network n) => monoNetworks ? ink : Jabu.brandNetwork(n);

  /// Forma de botões e chips.
  OutlinedBorder pill({Color? side}) {
    if (bevel) return const Win95Border();
    if (radius == 0) {
      return RoundedRectangleBorder(
        side: BorderSide(color: side ?? line, width: borderWidth),
      );
    }
    return StadiumBorder(
      side: side == null
          ? BorderSide.none
          : BorderSide(color: side, width: borderWidth),
    );
  }

  /// Decoração de cartões e painéis.
  Decoration panel({Color? color, double base = 22, bool raised = true}) {
    if (bevel) {
      return ShapeDecoration(
        color: color ?? card,
        shape: Win95Border(sunken: !raised),
      );
    }
    return BoxDecoration(
      color: color ?? card,
      borderRadius: r(base),
      border: Border.all(color: line, width: borderWidth),
    );
  }

  /// Decoração com o gradiente de destaque.
  Decoration accentPanel({double base = 22}) {
    if (bevel) {
      return ShapeDecoration(gradient: accent, shape: const Win95Border());
    }
    return BoxDecoration(gradient: accent, borderRadius: r(base));
  }

  /// Títulos de seção ganham a "voz" do tema.
  String headline(String t) => switch (id) {
    JabuThemeId.ascii => '[ $t ]',
    JabuThemeId.matrix => '> ${t.toLowerCase()}_',
    _ => t,
  };

  @override
  JabuStyle copyWith() => this;

  @override
  JabuStyle lerp(JabuStyle? other, double t) => t < .5 ? this : (other ?? this);

  static JabuStyle of(JabuThemeId id) => switch (id) {
    JabuThemeId.system || JabuThemeId.jabuticaba => jabuticaba,
    JabuThemeId.polpa => polpa,
    JabuThemeId.paperwhite => paperwhite,
    JabuThemeId.win95 => win95,
    JabuThemeId.ascii => ascii,
    JabuThemeId.matrix => matrix,
    JabuThemeId.contraste => contraste,
  };

  static const jabuticaba = JabuStyle(
    id: JabuThemeId.jabuticaba,
    brightness: Brightness.dark,
    canvas: Color(0xFF0F0812),
    card: Color(0xFF1A1020),
    cardHigh: Color(0xFF24172B),
    line: Color(0xFF33243B),
    muted: Color(0xFFAA98B2),
    ink: Jabu.pulp,
    brand: Color(0xFFC58AF0),
    hot: Jabu.magenta,
    accent: Jabu.brandGradient,
    onAccent: Colors.white,
    glass: Color(0xCC140B18),
  );

  static const polpa = JabuStyle(
    id: JabuThemeId.polpa,
    brightness: Brightness.light,
    canvas: Color(0xFFF8F3F7),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFF1E8F0),
    line: Color(0xFFE6DAE4),
    muted: Color(0xFF7A6880),
    ink: Color(0xFF1C1020),
    brand: Jabu.plum,
    hot: Jabu.magenta,
    accent: Jabu.brandGradient,
    onAccent: Colors.white,
    glass: Color(0xD9FFFFFF),
  );

  static const paperwhite = JabuStyle(
    id: JabuThemeId.paperwhite,
    brightness: Brightness.light,
    canvas: Color(0xFFF3EFE4),
    card: Color(0xFFF9F6EE),
    cardHigh: Color(0xFFE9E3D4),
    line: Color(0xFFD6CEBC),
    muted: Color(0xFF6E675C),
    ink: Color(0xFF1E1C19),
    brand: Color(0xFF1E1C19),
    hot: Color(0xFF1E1C19),
    accent: LinearGradient(colors: [Color(0xFF2A2824), Color(0xFF2A2824)]),
    onAccent: Color(0xFFF3EFE4),
    glass: Color(0xF2F3EFE4),
    radius: 8,
    displayFont: 'Literata',
    bodyFont: 'Literata',
    displayWeight: FontWeight.w700,
    monoNetworks: true,
    imageFilter: _grayscale,
    blur: false,
  );

  static const win95 = JabuStyle(
    id: JabuThemeId.win95,
    brightness: Brightness.light,
    canvas: Color(0xFFC0C0C0),
    card: Color(0xFFC0C0C0),
    cardHigh: Color(0xFFDFDFDF),
    line: Color(0xFF808080),
    muted: Color(0xFF3A3A3A),
    ink: Color(0xFF000000),
    brand: Color(0xFF000080),
    hot: Color(0xFF000080),
    accent: LinearGradient(colors: [Color(0xFF000080), Color(0xFF1084D0)]),
    onAccent: Colors.white,
    glass: Color(0xFFC0C0C0),
    radius: 0,
    displayFont: 'Pixelify',
    bodyFont: 'Pixelify',
    displayWeight: FontWeight.w700,
    bevel: true,
    titleBar: Color(0xFF000080),
    onTitleBar: Colors.white,
    solidSelection: true,
    blur: false,
    sizeScale: 1.05,
  );

  static const ascii = JabuStyle(
    id: JabuThemeId.ascii,
    brightness: Brightness.light,
    canvas: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    cardHigh: Color(0xFFF0F0F0),
    line: Color(0xFF000000),
    muted: Color(0xFF555555),
    ink: Color(0xFF000000),
    brand: Color(0xFF000000),
    hot: Color(0xFF000000),
    accent: LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]),
    onAccent: Colors.white,
    glass: Color(0xFFFFFFFF),
    radius: 0,
    displayFont: 'PlexMono',
    bodyFont: 'PlexMono',
    displayWeight: FontWeight.w700,
    monoNetworks: true,
    imageFilter: _inked,
    solidSelection: true,
    blur: false,
    sizeScale: .94,
  );

  static const matrix = JabuStyle(
    id: JabuThemeId.matrix,
    brightness: Brightness.dark,
    canvas: Color(0xFF000500),
    card: Color(0xFF00120A),
    cardHigh: Color(0xFF002010),
    line: Color(0xFF0B4D1F),
    muted: Color(0xFF15A63A),
    ink: Color(0xFF39FF6A),
    brand: Color(0xFF39FF6A),
    hot: Color(0xFFB4FFC6),
    accent: LinearGradient(colors: [Color(0xFF00C832), Color(0xFF39FF6A)]),
    onAccent: Colors.black,
    glass: Color(0xF0000500),
    radius: 0,
    displayFont: 'VT323',
    bodyFont: 'PlexMono',
    displayWeight: FontWeight.w400,
    monoNetworks: true,
    imageFilter: _phosphor,
    glow: [Shadow(color: Color(0xAA39FF6A), blurRadius: 10)],
    blur: false,
    sizeScale: .94,
  );

  static const contraste = JabuStyle(
    id: JabuThemeId.contraste,
    brightness: Brightness.dark,
    canvas: Color(0xFF000000),
    card: Color(0xFF000000),
    cardHigh: Color(0xFF1A1A1A),
    line: Color(0xFFFFFFFF),
    muted: Color(0xFFE6E6E6),
    ink: Color(0xFFFFFFFF),
    brand: Color(0xFFFFD400),
    hot: Color(0xFFFFD400),
    accent: LinearGradient(colors: [Color(0xFFFFD400), Color(0xFFFFD400)]),
    onAccent: Colors.black,
    glass: Color(0xFF000000),
    radius: 12,
    borderWidth: 2,
    solidSelection: true,
    blur: false,
    sizeScale: 1.06,
  );
}

/// Relevo clássico do Windows 95: luz em cima/esquerda, sombra embaixo/direita.
class Win95Border extends OutlinedBorder {
  const Win95Border({this.sunken = false, super.side});
  final bool sunken;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(2);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect.deflate(2));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    const white = Color(0xFFFFFFFF);
    const light = Color(0xFFDFDFDF);
    const dark = Color(0xFF808080);
    const black = Color(0xFF0A0A0A);
    final outerTL = sunken ? dark : white;
    final outerBR = sunken ? white : black;
    final innerTL = sunken ? black : light;
    final innerBR = sunken ? light : dark;
    final p = Paint()..strokeWidth = 1;
    void lines(Rect r, Color tl, Color br) {
      p.color = tl;
      canvas.drawLine(r.topLeft, r.topRight.translate(-1, 0), p);
      canvas.drawLine(r.topLeft, r.bottomLeft.translate(0, -1), p);
      p.color = br;
      canvas.drawLine(
        r.bottomLeft.translate(0, -.5),
        r.bottomRight.translate(0, -.5),
        p,
      );
      canvas.drawLine(
        r.topRight.translate(-.5, 0),
        r.bottomRight.translate(-.5, 0),
        p,
      );
    }

    lines(rect.deflate(.5), outerTL, outerBR);
    lines(rect.deflate(1.5), innerTL, innerBR);
  }

  @override
  ShapeBorder scale(double t) => this;

  @override
  Win95Border copyWith({BorderSide? side}) =>
      Win95Border(sunken: sunken, side: side ?? this.side);
}

extension JabuContext on BuildContext {
  JabuStyle get jc => Theme.of(this).extension<JabuStyle>()!;
  ColorScheme get cs => Theme.of(this).colorScheme;
  TextTheme get tt => Theme.of(this).textTheme;
  bool get isWide => MediaQuery.sizeOf(this).width >= 900;
}

ThemeData buildTheme(JabuStyle s) {
  final ink = s.ink;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: s.brand,
        brightness: s.brightness,
      ).copyWith(
        primary: s.brand,
        onPrimary: s.onAccent,
        secondary: s.hot,
        tertiary: Jabu.leaf,
        surface: s.canvas,
        onSurface: ink,
        surfaceContainerHighest: s.cardHigh,
        surfaceContainerHigh: s.cardHigh,
        surfaceContainer: s.card,
        surfaceContainerLow: s.card,
        secondaryContainer: s.solidSelection
            ? s.brand
            : s.brand.withValues(alpha: .2),
        onSecondaryContainer: s.solidSelection ? s.onAccent : ink,
        outline: s.line,
        outlineVariant: s.line,
      );
  final k = s.sizeScale;

  TextStyle display(double size, [FontWeight? w]) => TextStyle(
    fontFamily: s.displayFont,
    fontSize: size * k * (s.displayFont == 'VT323' ? 1.3 : 1),
    fontWeight: w ?? s.displayWeight,
    height: 1.08,
    letterSpacing: s.displayFont == 'Bricolage' ? -.5 : 0,
    color: ink,
    shadows: s.glow,
  );

  TextStyle body(
    double size, {
    FontWeight w = FontWeight.w400,
    Color? color,
    double height = 1.45,
  }) => TextStyle(
    fontFamily: s.bodyFont,
    fontSize: size * k,
    fontWeight: w,
    height: height,
    color: color ?? ink,
  );

  final text = TextTheme(
    displayLarge: display(52),
    displayMedium: display(40),
    displaySmall: display(32),
    headlineLarge: display(28),
    headlineMedium: display(
      24,
      s.displayWeight == FontWeight.w800 ? FontWeight.w700 : null,
    ),
    headlineSmall: display(
      20,
      s.displayWeight == FontWeight.w800 ? FontWeight.w700 : null,
    ),
    titleLarge: body(18, w: FontWeight.w700, height: 1.3),
    titleMedium: body(15.5, w: FontWeight.w700, height: 1.3),
    titleSmall: body(14, w: FontWeight.w600, height: 1.3),
    bodyLarge: body(16),
    bodyMedium: body(14.5),
    bodySmall: body(12.5, color: s.muted, height: 1.35),
    labelLarge: body(14, w: FontWeight.w700, height: 1.2),
    labelMedium: body(12.5, w: FontWeight.w600, color: s.muted, height: 1.2),
    labelSmall: body(
      11,
      w: FontWeight.w700,
      color: s.muted,
      height: 1.2,
    ).copyWith(letterSpacing: .3),
  );

  final pill = s.pill();
  final buttonText = TextStyle(
    fontFamily: s.bodyFont,
    fontWeight: FontWeight.w700,
    fontSize: 15 * k,
  );
  final inputRadius = s.radius == 0
      ? BorderRadius.zero
      : BorderRadius.circular(40);
  final bar = s.titleBar ?? s.canvas;

  return ThemeData(
    useMaterial3: true,
    brightness: s.brightness,
    colorScheme: scheme,
    fontFamily: s.bodyFont,
    textTheme: text,
    scaffoldBackgroundColor: s.canvas,
    canvasColor: s.canvas,
    extensions: [s],
    splashFactory: s.retro ? NoSplash.splashFactory : InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(
      color: s.line,
      thickness: s.borderWidth,
      space: 1,
    ),
    iconTheme: IconThemeData(color: ink),
    appBarTheme: AppBarTheme(
      backgroundColor: bar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.headlineSmall?.copyWith(
        color: s.onTitleBar ?? ink,
        shadows: s.glow,
      ),
      foregroundColor: s.onTitleBar ?? ink,
      iconTheme: IconThemeData(color: s.onTitleBar ?? ink),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: s.card,
      selectedColor: s.solidSelection
          ? s.brand
          : s.brand.withValues(alpha: .18),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        color: s.solidSelection ? s.onAccent : ink,
      ),
      side: s.bevel
          ? BorderSide.none
          : BorderSide(color: s.line, width: s.borderWidth),
      shape: pill,
      labelStyle: text.labelLarge,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        backgroundColor: s.bevel ? s.card : s.brand,
        foregroundColor: s.bevel ? ink : s.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: buttonText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: s.pill(side: s.line),
        side: s.bevel
            ? BorderSide.none
            : BorderSide(color: s.line, width: s.borderWidth),
        backgroundColor: s.bevel ? s.card : null,
        foregroundColor: ink,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: buttonText,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: pill,
        foregroundColor: s.brand,
        textStyle: buttonText,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        shape: pill,
        side: BorderSide(color: s.line, width: s.borderWidth),
        selectedBackgroundColor: s.solidSelection
            ? s.brand
            : s.brand.withValues(alpha: .18),
        selectedForegroundColor: s.solidSelection ? s.onAccent : ink,
        textStyle: buttonText.copyWith(fontSize: 13.5 * k),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.onAccent : s.muted,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (st) => st.contains(WidgetState.selected) ? s.brand : s.cardHigh,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: s.bevel ? Colors.white : s.card,
      hintStyle: TextStyle(color: s.muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: s.line, width: s.borderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: s.line, width: s.borderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: inputRadius,
        borderSide: BorderSide(color: s.brand, width: 1.6),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: s.card,
      surfaceTintColor: Colors.transparent,
      showDragHandle: !s.retro,
      shape: s.bevel
          ? const Win95Border()
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(s.radius == 0 ? 0 : 28),
              ),
            ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: s.card,
      shape: s.bevel
          ? const Win95Border()
          : RoundedRectangleBorder(borderRadius: s.r(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: s.dark ? s.cardHigh : s.ink,
      contentTextStyle: text.bodyMedium?.copyWith(
        color: s.dark ? ink : s.canvas,
      ),
      shape: s.bevel
          ? const Win95Border()
          : RoundedRectangleBorder(borderRadius: s.r(16)),
    ),
    listTileTheme: ListTileThemeData(iconColor: ink, textColor: ink),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: s.brand),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}
