import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:intl/intl.dart' show NumberFormat;
import 'dart:math' show min, max;

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
  final String prefix; // String before the value; may be null
  final String postfix; // String after the value; may be null

  ValueBox(
      {@required this.value,
      @required this.label,
      @required this.format,
      @required this.color,
      this.units,
      this.prefix,
      this.postfix}) {
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
        child: Stack(
          children: <Widget>[
            Text(label, style: TextStyle(fontSize: 10)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 10),
                Expanded(
                  child: DecimalAlignedText(
                      value: value,
                      prefix: prefix,
                      postfix: postfix,
                      units: units,
                      unitsFontSize: 10,
                      format: format,
                      color: color),
                )
              ],
            ),
          ],
        ));
  }
}

/// A box that shows a numeric value, along with a label and units.
///
class DecimalAlignedText extends StatefulWidget {
  final String value; // may be null
  final String format;

  /// Shown before the value
  final String prefix; // may be null
  /// Shown after the value
  final String postfix; // may be null
  final String units;
  final double unitsFontSize;

  /// fraction of the size the value is rendered in for the units.
  /// Ignored if unitsFontSize is set and the value's font size
  /// is >= unitsFontSize.
  final double unitsFontSizeFraction;
  final Color color;
  final double scale;

  /// True if the height of the value should be computed using the baseline.
  /// Use false if the value has lower-case letters in it.
  final bool useBaseline;

  /// [scale] is how completely the box is filled.  By default, it's 0.95,
  /// to give a little margin for error if the format string isn't exactly
  /// as wide as the widest value when rendered.
  DecimalAlignedText(
      {@required this.value,
      @required this.format,
      @required this.color,
      this.prefix,
      this.postfix,
      this.units,
      this.unitsFontSize,
      this.unitsFontSizeFraction = 0.5,
      this.scale = 0.95,
      this.useBaseline = true}) {
    assert(format != null);
    assert(color != null);
  }

  @override
  _DecimalAlignedTextState createState() => _DecimalAlignedTextState();
}

class _DecimalAlignedTextState extends State<DecimalAlignedText> {
  NumberFormat numberFormat;
  int decimalIndex; // If no decimal, length of format string
  double valueBeforeWidth; // Width of the part of the value before '.'
  double valueAfterWidth; // Including decimal point
  double prefixWidth;
  double postfixWidth;
  double valueTotalWidth;
  double valueHeight;
  double unitsHeight;
  double unitsWidth;

  @override
  void initState() {
    super.initState();
    decimalIndex = widget.format.indexOf('.');
    RenderParagraph p;
    if (decimalIndex == -1) {
      decimalIndex = widget.format.length;
      valueAfterWidth = 0;
      valueHeight = 0;
    } else {
      p = getParagraph(100, widget.format.substring(decimalIndex));
      valueAfterWidth = p.getMaxIntrinsicWidth(double.infinity);
      if (widget.useBaseline) {
        valueHeight =
            p.computeDistanceToActualBaseline(TextBaseline.alphabetic);
      } else {
        valueHeight = p.getMaxIntrinsicHeight(double.infinity);
      }
    }
    {
      p = getParagraph(100, widget.format.substring(0, decimalIndex));
      if (widget.useBaseline) {
        valueHeight = max(valueHeight,
            p.computeDistanceToActualBaseline(TextBaseline.alphabetic));
      } else {
        valueHeight =
            max(valueHeight, p.getMaxIntrinsicHeight(double.infinity));
      }
      valueBeforeWidth = p.getMaxIntrinsicWidth(double.infinity);
    }
    if (widget.prefix == null) {
      prefixWidth = 0;
    } else {
      p = getParagraph(100, widget.prefix);
      prefixWidth = p.getMaxIntrinsicWidth(double.infinity);
    }
    if (widget.postfix == null) {
      postfixWidth = 0;
    } else {
      p = getParagraph(100, widget.postfix);
      postfixWidth = p.getMaxIntrinsicWidth(double.infinity);
    }
    valueTotalWidth =
        valueBeforeWidth + valueAfterWidth + prefixWidth + postfixWidth;
    if (widget.units == null) {
      unitsHeight = 0;
      unitsWidth = 0;
    } else {
      if (widget.unitsFontSize != null) {
        p = getParagraph(widget.unitsFontSize, widget.units);
      } else {
        p = getParagraph(100 * widget.unitsFontSizeFraction, widget.units);
      }
      unitsHeight = p.getMaxIntrinsicHeight(double.infinity);
      unitsWidth = p.getMaxIntrinsicWidth(double.infinity);
    }
  }

  RenderParagraph getParagraph(double fontSize, String s) {
    final p = RenderParagraph(
        TextSpan(
            text: s, style: TextStyle(fontSize: fontSize, color: widget.color)),
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
    double fontSize = 100.0 * widget.scale * size.width / state.valueTotalWidth;
    // Font size based on width.  If height is constrained, this can go down.
    double unitsHeight = 0.0;
    double unitsWidth = 0.0;
    double unitsFontSize;
    if (widget.units == null) {
      fontSize =
          min(fontSize, 100.0 * widget.scale * size.height / state.valueHeight);
    } else {
      if (widget.unitsFontSize != null) {
        fontSize = min(
            fontSize,
            100.0 *
                widget.scale *
                (size.height - state.unitsHeight * 1.2) /
                state.valueHeight);
        if (widget.unitsFontSize > fontSize) {
          // Edge case:  we've run out of vertical space for the units
          fontSize = 100.0 *
              widget.scale *
              min(
                  size.width / state.valueTotalWidth,
                  size.height /
                      (state.valueHeight * (1 + widget.unitsFontSizeFraction)));
          unitsFontSize = fontSize * widget.unitsFontSizeFraction;
          if (state.unitsWidth * unitsFontSize / widget.unitsFontSize >
              size.width) {
            unitsFontSize =
                size.width * widget.unitsFontSize / state.unitsWidth;
          }
          unitsHeight =
              state.unitsHeight * unitsFontSize / widget.unitsFontSize;
          unitsWidth = state.unitsWidth * unitsFontSize / widget.unitsFontSize;
        } else {
          unitsFontSize = widget.unitsFontSize;
          unitsHeight = state.unitsHeight;
          unitsWidth = state.unitsWidth;
          if (state.unitsWidth > size.width) {
            unitsFontSize *= size.width / state.unitsWidth;
            unitsHeight *= size.width / state.unitsWidth;
            unitsWidth = size.width;
          }
        }
      } else {
        // Relative unitsFontSize
        fontSize = min(
            fontSize,
            100.0 *
                widget.scale *
                size.height /
                (state.valueHeight + state.unitsHeight));
        unitsFontSize = fontSize * widget.unitsFontSizeFraction;
        unitsHeight = state.unitsHeight;
        unitsWidth = state.unitsWidth;
        if (state.unitsWidth > size.width) {
          unitsFontSize *= size.width / state.unitsWidth;
          unitsHeight *= size.width / state.unitsWidth;
          unitsWidth = size.width;
        }
      }
    }
    final double vh = state.valueHeight * fontSize / 100.0; // Value height
    double vdy = 0; // Amount to scoot value up by for units
    if (widget.units != null) {
      final available = size.height - (unitsHeight + vh);
      final taken = min(unitsHeight / 2, available / 3);
      final x = (size.width - unitsWidth) / 2;
      final y = (size.height + vh + taken - unitsHeight) / 2;
      vdy = -(taken + unitsHeight) / 2;
      // For the whitespace below the value, take no more than the height
      // of units.  If constrained, split evenly between the margins
      // and the gap.
      final style = TextStyle(color: widget.color, fontSize: unitsFontSize);
      final span = TextSpan(text: widget.units, style: style);
      _paintText(x, y, span, canvas);
    }
    final double prefixW = state.prefixWidth * fontSize / 100.0;
    final double beforeW = state.valueBeforeWidth * fontSize / 100.0;
    final double afterW = state.valueAfterWidth * fontSize / 100.0;
    final double postfixW = state.postfixWidth * fontSize / 100.0;
    final double totalW = prefixW + beforeW + afterW + postfixW;
    final double y = vdy + (size.height - vh) / 2.0;
    final style = TextStyle(color: widget.color, fontSize: fontSize);
    double x = (size.width - totalW) / 2.0;
    if (widget.prefix != null) {
      final span = TextSpan(text: widget.prefix, style: style);
      _paintText(x, y, span, canvas);
      x += prefixW;
    }
    if (value == null) {
      x += beforeW + afterW;
    } else {
      int decimalIndex = value.indexOf('.');
      if (decimalIndex == -1) {
        decimalIndex = value.length;
      }
      {  // units part:
        final span =
        TextSpan(text: value.substring(0, decimalIndex), style: style);
        final p = RenderParagraph(span,
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left);
        p.layout(BoxConstraints());
        final double beforeReal = p.getMaxIntrinsicWidth(double.infinity);
        x += beforeW;
        _paintText(x - beforeReal, y, span, canvas);
      }
      if (decimalIndex != value.length) {
        final span = TextSpan(
          text: value.substring(decimalIndex), style: style);
        _paintText(x, y, span, canvas);
      }
      x += afterW;
    }
    if (widget.postfix != null) {
      final span = TextSpan(text: widget.postfix, style: style);
      _paintText(x, y, span, canvas);
    }
  }

  void _paintText(
      double x, double y, TextSpan span, Canvas canvas) {
    final offset = Offset(x, y);
    final painter = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: 1);
    painter.layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_ValueBoxPainter oldDelegate) {
    return this.value != oldDelegate.value;
  }
}
