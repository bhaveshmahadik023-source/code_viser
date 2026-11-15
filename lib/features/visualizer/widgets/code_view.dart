import 'dart:math' as math;

import 'package:flutter/material.dart';

// Finds comments, strings, keywords, built-in names and numbers.
final RegExp _tokenRe = RegExp(
  r'''(#.*$)|("[^"]*"|'[^']*')|\b(def|if|elif|else|for|while|in|not|and|or|return|break|continue|pass|is|True|False|None)\b|\b(print|len|range|int|float|str|abs|min|max|sum|list|enumerate|round)\b|\b(\d+\.?\d*)\b''',
);

/// Read-only code viewer with line numbers, simple syntax colors and
/// a highlighted active line. It scrolls by itself to the active line.
class CodeView extends StatefulWidget {
  const CodeView({
    super.key,
    required this.code,
    required this.activeLine,
    this.maxHeight = 460,
  });

  final String code;

  /// Line to highlight (1-based, 0 = none).
  final int activeLine;
  final double maxHeight;

  @override
  State<CodeView> createState() => _CodeViewState();
}

class _CodeViewState extends State<CodeView> {
  static const double _lineHeight = 24;

  final ScrollController _scroll = ScrollController();
  late List<String> _lines;

  @override
  void initState() {
    super.initState();
    _lines = widget.code.split('\n');
  }

  @override
  void didUpdateWidget(CodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.code != widget.code) {
      _lines = widget.code.split('\n');
    }
    if (oldWidget.activeLine != widget.activeLine) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Scrolls so that the active line is in the middle.
  void _scrollToActive() {
    final i = widget.activeLine - 1;
    if (i < 0 || !_scroll.hasClients) return;
    final viewport = _scroll.position.viewportDimension;
    final target = (i * _lineHeight) - viewport / 2 + _lineHeight / 2;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  TextSpan _highlight(String line, ColorScheme scheme, TextStyle base) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _tokenRe.allMatches(line)) {
      if (m.start > last) {
        spans.add(TextSpan(text: line.substring(last, m.start)));
      }
      Color color;
      FontWeight? weight;
      if (m.group(1) != null) {
        color = scheme.outline; // comment
      } else if (m.group(2) != null) {
        color = Colors.green.shade400; // string
      } else if (m.group(3) != null) {
        color = scheme.primary; // keyword
        weight = FontWeight.bold;
      } else if (m.group(4) != null) {
        color = scheme.tertiary; // built-in function
      } else {
        color = Colors.orange.shade400; // number
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(color: color, fontWeight: weight),
      ));
      last = m.end;
    }
    if (last < line.length) {
      spans.add(TextSpan(text: line.substring(last)));
    }
    return TextSpan(style: base, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = TextStyle(
      fontFamily: 'monospace',
      fontSize: 13.5,
      color: scheme.onSurface,
    );
    final height =
        math.min(_lines.length * _lineHeight + 16, widget.maxHeight);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: height,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _lines.length; i++)
                SizedBox(
                  height: _lineHeight,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.centerLeft,
                    decoration: BoxDecoration(
                      color: i + 1 == widget.activeLine
                          ? scheme.primary.withValues(alpha: 0.22)
                          : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          width: 3,
                          color: i + 1 == widget.activeLine
                              ? scheme.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: Text(
                            '${i + 1}',
                            style: base.copyWith(color: scheme.outline),
                          ),
                        ),
                        Expanded(
                          child: Text.rich(
                            _highlight(_lines[i], scheme, base),
                            softWrap: false,
                            overflow: TextOverflow.fade,
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
    );
  }
}