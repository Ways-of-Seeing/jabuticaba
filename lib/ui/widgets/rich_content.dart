import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../../models/models.dart';
import '../nav.dart';
import '../theme.dart';

/// Renderiza o texto de um post (HTML do Mastodon ou texto puro do Bluesky,
/// Lemmy e Loops) com links, hashtags e menções tocáveis.
class RichContent extends StatefulWidget {
  const RichContent({
    super.key,
    this.html,
    this.text = '',
    this.maxLines,
    this.style,
    this.network,
  });

  final String? html;
  final String text;
  final int? maxLines;
  final TextStyle? style;
  final Network? network;

  @override
  State<RichContent> createState() => _RichContentState();
}

class _RichContentState extends State<RichContent> {
  final _recognizers = <TapGestureRecognizer>[];

  static final _plain = RegExp(
    r'(https?://[^\s]+)|(#[\p{L}\p{N}_]+)|(@[\w.\-]+(?:@[\w.\-]+\.[a-z]{2,})?)',
    unicode: true,
  );

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _tap(VoidCallback f) {
    final r = TapGestureRecognizer()..onTap = f;
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final base = widget.style ?? context.tt.bodyLarge!;
    final link = base.copyWith(
      color: context.cs.primary,
      fontWeight: FontWeight.w600,
    );
    final spans = widget.html != null && widget.html!.isNotEmpty
        ? _fromHtml(widget.html!, base, link)
        : _fromText(widget.text, base, link);
    _trimTrailing(spans);
    if (spans.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: spans, style: base),
      maxLines: widget.maxLines,
      overflow: widget.maxLines == null
          ? TextOverflow.clip
          : TextOverflow.ellipsis,
    );
  }

  void _trimTrailing(List<InlineSpan> spans) {
    while (spans.isNotEmpty) {
      final last = spans.last;
      if (last is TextSpan &&
          last.recognizer == null &&
          (last.text ?? '').trim().isEmpty &&
          last.children == null) {
        spans.removeLast();
      } else if (last is TextSpan &&
          last.recognizer == null &&
          last.children == null &&
          last.text != null &&
          last.text!.endsWith('\n')) {
        spans[spans.length - 1] = TextSpan(
          text: last.text!.trimRight(),
          style: last.style,
        );
        break;
      } else {
        break;
      }
    }
  }

  void _onTag(String tag) => openTag(context, tag.replaceFirst('#', ''));

  void _onMention(String href, String text) {
    final uri = Uri.tryParse(href);
    final user = text.replaceFirst('@', '').split('@').first;
    if (widget.network == Network.bluesky) {
      openHandle(context, text.replaceFirst('@', ''), Network.bluesky);
    } else if (uri != null && uri.host.isNotEmpty) {
      openHandle(context, '$user@${uri.host}', Network.mastodon);
    } else {
      openUrl(href);
    }
  }

  List<InlineSpan> _fromText(String text, TextStyle base, TextStyle link) {
    final out = <InlineSpan>[];
    var last = 0;
    for (final m in _plain.allMatches(text)) {
      if (m.start > last) {
        out.add(TextSpan(text: text.substring(last, m.start)));
      }
      final s = m[0]!;
      if (m[1] != null) {
        final clean = s.replaceAll(RegExp(r'[.,;:!?)\]]+$'), '');
        out.add(
          TextSpan(
            text: _shortUrl(clean),
            style: link,
            recognizer: _tap(() => openUrl(clean)),
          ),
        );
        if (clean.length < s.length) {
          out.add(TextSpan(text: s.substring(clean.length)));
        }
      } else if (m[2] != null) {
        out.add(
          TextSpan(text: s, style: link, recognizer: _tap(() => _onTag(s))),
        );
      } else {
        out.add(
          TextSpan(
            text: s,
            style: link,
            recognizer: _tap(() => _onMention('', s)),
          ),
        );
      }
      last = m.end;
    }
    if (last < text.length) out.add(TextSpan(text: text.substring(last)));
    return out;
  }

  String _shortUrl(String url) {
    final u = url.replaceFirst(RegExp(r'^https?://(www\.)?'), '');
    return u.length > 34 ? '${u.substring(0, 32)}…' : u;
  }

  List<InlineSpan> _fromHtml(String html, TextStyle base, TextStyle link) {
    final frag = html_parser.parseFragment(html);
    final out = <InlineSpan>[];
    var firstBlock = true;

    void walk(dom.Node node) {
      if (node is dom.Text) {
        out.add(TextSpan(text: node.text));
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName;
      final classes = node.classes;
      if (classes.contains('invisible')) return;
      switch (tag) {
        case 'br':
          out.add(const TextSpan(text: '\n'));
        case 'p':
          if (!firstBlock) out.add(const TextSpan(text: '\n\n'));
          firstBlock = false;
          node.nodes.forEach(walk);
        case 'a':
          final href = node.attributes['href'] ?? '';
          final visible = _visibleText(node);
          if (classes.contains('hashtag') ||
              href.contains('/tags/') ||
              visible.startsWith('#')) {
            out.add(
              TextSpan(
                text: visible,
                style: link,
                recognizer: _tap(() => _onTag(visible)),
              ),
            );
          } else if (classes.contains('mention') || visible.startsWith('@')) {
            out.add(
              TextSpan(
                text: visible,
                style: link,
                recognizer: _tap(() => _onMention(href, visible)),
              ),
            );
          } else {
            out.add(
              TextSpan(
                text: visible,
                style: link,
                recognizer: _tap(() => openUrl(href)),
              ),
            );
          }
        case 'ul' || 'ol':
          for (final li in node.children) {
            out.add(const TextSpan(text: '\n• '));
            li.nodes.forEach(walk);
          }
        case 'strong' || 'b':
          final start = out.length;
          node.nodes.forEach(walk);
          _restyle(out, start, const TextStyle(fontWeight: FontWeight.w700));
        case 'em' || 'i':
          final start = out.length;
          node.nodes.forEach(walk);
          _restyle(out, start, const TextStyle(fontStyle: FontStyle.italic));
        case 'blockquote':
          out.add(const TextSpan(text: '\n'));
          final start = out.length;
          node.nodes.forEach(walk);
          _restyle(out, start, TextStyle(color: context.jc.muted));
        default:
          node.nodes.forEach(walk);
      }
    }

    frag.nodes.forEach(walk);
    return out;
  }

  void _restyle(List<InlineSpan> spans, int from, TextStyle extra) {
    for (var i = from; i < spans.length; i++) {
      final s = spans[i];
      if (s is TextSpan) {
        spans[i] = TextSpan(
          text: s.text,
          children: s.children,
          recognizer: s.recognizer,
          style: (s.style ?? const TextStyle()).merge(extra),
        );
      }
    }
  }

  String _visibleText(dom.Element a) {
    final b = StringBuffer();
    void walk(dom.Node n) {
      if (n is dom.Text) {
        b.write(n.text);
      } else if (n is dom.Element) {
        if (n.classes.contains('invisible')) return;
        n.nodes.forEach(walk);
        if (n.classes.contains('ellipsis')) b.write('…');
      }
    }

    a.nodes.forEach(walk);
    return b.toString();
  }
}
