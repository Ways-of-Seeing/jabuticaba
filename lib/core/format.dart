import 'package:html/parser.dart' as html_parser;

const _months = [
  'jan',
  'fev',
  'mar',
  'abr',
  'mai',
  'jun',
  'jul',
  'ago',
  'set',
  'out',
  'nov',
  'dez',
];

String timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inSeconds < 60) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  final local = date.toLocal();
  final now = DateTime.now();
  final base = '${local.day} ${_months[local.month - 1]}';
  return local.year == now.year ? base : '$base ${local.year}';
}

String compact(int? n) {
  if (n == null) return '–';
  if (n < 1000) return '$n';
  String trim(double v) {
    final s = v.toStringAsFixed(v < 10 ? 1 : 0);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (n < 1000000) return '${trim(n / 1000).replaceAll('.', ',')} mil';
  return '${trim(n / 1000000).replaceAll('.', ',')} mi';
}

String duration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  if (m >= 60) {
    return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Converte HTML de um post em texto simples (para prévias e buscas).
String htmlToText(String? html) {
  if (html == null || html.isEmpty) return '';
  final doc = html_parser.parseFragment(
    html.replaceAll(RegExp(r'<br\s*/?>'), '\n').replaceAll('</p>', '\n\n'),
  );
  return doc.text?.trim().replaceAll(RegExp(r'\n{3,}'), '\n\n') ?? '';
}

/// Markdown leve (Lemmy) → texto simples.
String stripMarkdown(String? md) {
  if (md == null) return '';
  return md
      .replaceAllMapped(RegExp(r'!\[[^\]]*\]\(([^)]+)\)'), (_) => '')
      .replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (m) => m[1]!)
      .replaceAll(RegExp(r'^\s*[-*_]{3,}\s*$', multiLine: true), '')
      .replaceAll(RegExp(r'[*_`>#]{1,3}'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

String hostOf(String? url) {
  if (url == null) return '';
  return Uri.tryParse(url)?.host.replaceFirst('www.', '') ?? '';
}
