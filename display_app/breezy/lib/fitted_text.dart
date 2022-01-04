import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'dart:math' show min;

/*
MIT License

Copyright (c) 2020,2021 Bill Foote

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
 */

/// A text field that aligns itself to the available space
class FittedText extends StatefulWidget {
  final String value;
  final TextStyle style;
  final bool useBaseline;

  FittedText(this.value, {Key key, this.style, this.useBaseline = false})
      : super(key: key) {
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
    final y = (size.height - (state.valueHeight * fontSize / 100.0)) / 2;

    painter.layout();
    painter.paint(canvas, Offset(0, y));
  }

  @override
  bool shouldRepaint(_FittedTextPainter oldDelegate) {
    return this.value != oldDelegate.value || this.style != oldDelegate.style;
  }
}
