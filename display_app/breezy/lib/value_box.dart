import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:intl/intl.dart' show NumberFormat;
import 'dart:math' show min;

/*
MIT License

Copyright (c) 2020 Bill Foote

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

class ValueBox extends StatelessWidget {
  static final _borderColor = Colors.grey[700];

  final String value; // may be null
  final String label;
  final String format;
  final Color color;
  final String units;

  ValueBox(
      {@required this.value,
      @required this.label,
      @required this.format,
      @required this.color,
      this.units = 'bar'}) {
    assert(label != null);
    assert(format != null);
    assert(color != null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.all(2.0),
        constraints: BoxConstraints.expand(),
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(width: 1, color: _borderColor),
                left: BorderSide(width: 1, color: _borderColor))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 10)),
            Expanded(
              child: DecimalAlignedText(
                  value: value, format: format, color: color),
            ),
            Center(child: Text(units, style: TextStyle(fontSize: 10, color: color))),
          ],
        ));
  }
}

/// A box that shows a numeric value, along with a label and units.
///
class DecimalAlignedText extends StatefulWidget {
  final String value; // may be null
  final String format;
  final Color color;
  final double scale;

  /// [scale] is how completely the box is filled.  By default, it's 0.95,
  /// to give a little margin for error if the format string isn't exactly
  /// as wide as the widest value when rendered.
  DecimalAlignedText(
      {@required this.value,
      @required this.format,
      @required this.color,
      this.scale = 0.95}) {
    assert(format != null);
    assert(color != null);
  }

  @override
  _DecimalAlignedTextState createState() => _DecimalAlignedTextState();
}

class _DecimalAlignedTextState extends State<DecimalAlignedText> {
  NumberFormat numberFormat;
  int decimalIndex; // If no decimal, length of format string
  double unitsWidth;
  double fractionWidth; // Including decimal point
  double unitsHeight;

  @override
  void initState() {
    super.initState();
    decimalIndex = widget.format.indexOf('.');
    RenderParagraph p;
    if (decimalIndex == -1) {
      decimalIndex = widget.format.length;
      fractionWidth = 0;
    } else {
      p = getParagraph(
          100, widget.format.substring(decimalIndex), TextAlign.left);
      fractionWidth = p.getMaxIntrinsicWidth(double.infinity);
    }
    p = getParagraph(
        100, widget.format.substring(0, decimalIndex), TextAlign.right);
    unitsHeight = p.getMaxIntrinsicHeight(double.infinity);
    unitsWidth = p.getMaxIntrinsicWidth(double.infinity);
  }

  RenderParagraph getParagraph(double fontSize, String s, TextAlign a) {
    final p = RenderParagraph(
        TextSpan(
            text: s,
            style: TextStyle(
                fontSize: fontSize,
                // fontFamily: 'RobotoMono',
                color: widget.color)),
        maxLines: 1,
        textDirection: TextDirection.ltr,
        textAlign: a);
    p.layout(BoxConstraints());
    return p;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.expand(),
      child: CustomPaint(painter: _ValueBoxPainter(this)),
    );
  }
}

class _ValueBoxPainter extends CustomPainter {
  final _DecimalAlignedTextState state;
  final DecimalAlignedText widget;
  final String value;

  _ValueBoxPainter(this.state)
      : this.widget = state.widget,
        this.value = state.widget.value;

  @override
  void paint(Canvas canvas, Size size) {
    if (value == null) {
      return;
    }
    final double fontSize = 100.0 *
        widget.scale *
        min(size.width / (state.unitsWidth + state.fractionWidth),
            size.height / state.unitsHeight);
    int decimalIndex = value.indexOf('.');
    final double uw = state.unitsWidth * fontSize / 100.0;
    final double fw = state.fractionWidth * fontSize / 100.0;
    final double h = state.unitsHeight * fontSize / 100.0;
    final double y = (size.height - h) / 2.0;
    if (decimalIndex == -1) {
      decimalIndex = value.length;
    } else {
      final double x = (size.width - fw + uw) / 2;
      final offset = Offset(x, y);
      final span = TextSpan(
          text: value.substring(decimalIndex),
          style: TextStyle(color: widget.color, fontSize: fontSize));
      final painter = TextPainter(
          text: span,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
          maxLines: 1);
      painter.layout();
      painter.paint(canvas, offset);
    }
    {
      final span = TextSpan(
          text: value.substring(0, decimalIndex),
          style: TextStyle(color: widget.color, fontSize: fontSize));
      final p = RenderParagraph(span,
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left);
      p.layout(BoxConstraints());
      final double uwReal = p.getMaxIntrinsicWidth(double.infinity);
      final double x = (uw - uwReal) + (size.width - fw - uw) / 2;
      final offset = Offset(x, y);

      final painter = TextPainter(
          text: span,
          textAlign: TextAlign.right,
          textDirection: TextDirection.ltr,
          maxLines: 1);
      painter.layout();
      painter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(_ValueBoxPainter oldDelegate) {
    return this.value != oldDelegate.value;
  }
}
