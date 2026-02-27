import 'package:flutter/material.dart';

/// Expandable Text Widget - Shows "more" for long content
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final VoidCallback? onTap;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 5,
    this.style,
    this.onTap,
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        debugPrint('📏 ExpandableText:');
        debugPrint('   Width: ${constraints.maxWidth.toStringAsFixed(1)}px');
        debugPrint('   Text: "${widget.text.substring(0, widget.text.length > 50 ? 50 : widget.text.length)}..."');
        debugPrint('   Max lines: ${widget.maxLines}');
        
        final defaultStyle = const TextStyle(fontSize: 15, height: 1.4, color: Colors.white);
        final textSpan = TextSpan(
          text: widget.text,
          style: widget.style ?? defaultStyle,
        );

        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isTextOverflow = textPainter.didExceedMaxLines;
        final lineCount = textPainter.computeLineMetrics().length;
        
        debugPrint('   Lines: $lineCount | Overflow: $isTextOverflow');

        return GestureDetector(
          onTap: () {
            debugPrint('📱 ExpandableText TAPPED!');
            if (widget.onTap != null) {
              debugPrint('   Calling onTap callback');
              widget.onTap!();
            } else {
              debugPrint('   ⚠️ No onTap callback provided');
            }
          },
          behavior: HitTestBehavior.opaque, // Make entire area tappable
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.text,
                style: widget.style ?? const TextStyle(fontSize: 15, height: 1.4, color: Colors.white),
                maxLines: _isExpanded ? null : widget.maxLines,
                overflow: _isExpanded ? null : TextOverflow.ellipsis,
              ),
              if (isTextOverflow && !_isExpanded)
                GestureDetector(
                  onTap: () {
                    debugPrint('📱 "more" button TAPPED!');
                    if (widget.onTap != null) {
                      debugPrint('   Opening detail screen...');
                      widget.onTap!();
                    } else {
                      debugPrint('   Expanding inline...');
                      setState(() => _isExpanded = true);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Text(
                          'more',
                          style: TextStyle(
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.blue[600],
                        ),
                      ],
                    ),
                  ),
                ),
              if (_isExpanded && isTextOverflow)
                GestureDetector(
                  onTap: () => setState(() => _isExpanded = false),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'show less',
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}