import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:intl/intl.dart' show NumberFormat;
import 'dart:math' show min, max;

/// A text field that aligns itself to the available space
///
class FittedText extends StatefulWidget {
  final String value;
  final TextStyle style;
  final bool useBaseline;

  /// [scale] is how completely the box is filled.  By default, it's 0.95,
  /// to give a little margin for error if the format string isn't exactly
  /// as wide as the widest value when rendered.
  FittedText(this.value, {this.style, this.useBaseline = false}) {
    assert(value != null);
    assert(style == null || style.inherit);
    assert(useBaseline != null);
  }

  @override
  _FittedTextState createState() => _FittedTextState();
}

class _FittedTextState extends State<FittedText> {
  double valueWidth; // Width and height with a font size of 100
  double valueHeight;

  @override
  void initState() {
    super.initState();
    final RenderParagraph p = getParagraph(100, widget.value);
    valueWidth = p.getMaxIntrinsicWidth(double.infinity);
    if (widget.useBaseline) {
      valueHeight = p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    } else {
      valueHeight = p.getMaxIntrinsicHeight(double.infinity);
    }
  }

  RenderParagraph getParagraph(double fontSize, String s) {
    final p = RenderParagraph(
        TextSpan(
            text: s, style: TextStyle(fontSize: fontSize).merge(widget.style)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left);
    p.layout(BoxConstraints());
    return p;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      child: CustomPaint(painter: _FittedTextPainter(this)),
    );
  }
}

class _FittedTextPainter extends CustomPainter {
  final _FittedTextState state;
  final FittedText widget;
  final String value;
  final TextStyle style;

  _FittedTextPainter(this.state)
      : this.widget = state.widget,
        this.value = state.widget.value,
        this.style = state.widget.style;

  @override
  void paint(Canvas canvas, Size size) {
    if (state.valueWidth == 0 || state.valueHeight == 0) {
      return;
    }
    double fontSize = 100.0 *
        min(size.width / state.valueWidth, size.height / state.valueHeight);
    final span = TextSpan(
        text: value, style: TextStyle(fontSize: fontSize).merge(style));
    final painter = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: 1);
    painter.layout();
    painter.paint(canvas, const Offset(0, 0));
  }

  @override
  bool shouldRepaint(_FittedTextPainter oldDelegate) {
    return this.value != oldDelegate.value || this.style != oldDelegate.style;
  }
}
