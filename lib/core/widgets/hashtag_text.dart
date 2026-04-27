import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Renders post content with tappable #hashtags highlighted in green.
/// Supports maxLines + expand/collapse, replacing ExpandableText where hashtags are needed.
class HashtagText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;

  /// Called when non-hashtag body text is tapped (e.g. navigate to post detail).
  final VoidCallback? onBodyTap;

  /// Called when a #hashtag is tapped. Receives the word without '#'.
  final void Function(String tag)? onHashtagTap;

  const HashtagText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.onBodyTap,
    this.onHashtagTap,
  });

  @override
  State<HashtagText> createState() => _HashtagTextState();
}

class _HashtagTextState extends State<HashtagText> {
  bool _expanded = false;
  final _recs = <TapGestureRecognizer>[];

  @override
  void dispose() {
    _clearRecs();
    super.dispose();
  }

  @override
  void didUpdateWidget(HashtagText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) _clearRecs();
  }

  void _clearRecs() {
    for (final r in _recs) {
      r.dispose();
    }
    _recs.clear();
  }

  TapGestureRecognizer _rec(VoidCallback fn) {
    final r = TapGestureRecognizer()..onTap = fn;
    _recs.add(r);
    return r;
  }

  List<InlineSpan> _buildSpans(TextStyle base) {
    _clearRecs();
    final tagStyle = base.copyWith(
      color: const Color(0xFF00B96B),
      fontWeight: FontWeight.w600,
    );
    final spans = <InlineSpan>[];
    final regex = RegExp(r'#\w+');
    int cursor = 0;
    final text = widget.text;

    for (final m in regex.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, m.start),
          style: base,
          recognizer: widget.onBodyTap != null ? _rec(widget.onBodyTap!) : null,
        ));
      }
      final word = m.group(0)!.substring(1).toLowerCase();
      spans.add(TextSpan(
        text: m.group(0)!,
        style: tagStyle,
        recognizer: _rec(() => widget.onHashtagTap?.call(word)),
      ));
      cursor = m.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: base,
        recognizer: widget.onBodyTap != null ? _rec(widget.onBodyTap!) : null,
      ));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.style ??
        const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87);
    final effectiveMax = _expanded ? null : widget.maxLines;

    final rich = Text.rich(
      TextSpan(children: _buildSpans(base)),
      maxLines: effectiveMax,
      overflow: effectiveMax != null ? TextOverflow.ellipsis : null,
    );

    if (widget.maxLines == null) return rich;

    return LayoutBuilder(builder: (ctx, constraints) {
      final tp = TextPainter(
        text: TextSpan(text: widget.text, style: base),
        maxLines: widget.maxLines,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: constraints.maxWidth);
      final overflows = tp.didExceedMaxLines;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          rich,
          if (overflows && !_expanded)
            GestureDetector(
              onTap: widget.onBodyTap ?? () => setState(() => _expanded = true),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('more', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue[600]),
                  ],
                ),
              ),
            ),
          if (_expanded && overflows)
            GestureDetector(
              onTap: () => setState(() => _expanded = false),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('show less', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.w600, fontSize: 14)),
              ),
            ),
        ],
      );
    });
  }
}
