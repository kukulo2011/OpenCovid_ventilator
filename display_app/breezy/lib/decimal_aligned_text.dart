import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'package:intl/intl.dart' show NumberFormat;
import 'dart:math' show min, max;
import 'data_types.dart';

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

/// A box that shows a numeric or string value, along with a label and units.
/// The text is sized to fit in the available space, and the value can be
/// intelligently aligned.
class AlignedText extends StatefulWidget {
  final String value; // may be null
  final ValueAlignment alignment;
  final String format;

  /// Shown before the value
  final String prefix; // may be null
  /// Shown after the value
  final String postfix; // may be null
  final String units;

  /// Fraction of available height to use for the display of the units
  final double unitsHeightFraction;
  final Color color;
  final double scale;

  /// True if the height of the value should be computed using the baseline.
  /// Use false if the value has lower-case letters in it.
  final bool useBaseline;

  /// [scale] is how completely the box is filled.  By default, it's 0.95,
  /// to give a little margin for error if the format string isn't exactly
  /// as wide as the widest value when rendered.
  AlignedText(
      {@required this.value,
        @required this.alignment,
      @required this.format,
      @required this.color,
      this.prefix,
      this.postfix,
      this.units,
      this.unitsHeightFraction = 0.16,
      this.scale = 0.95,
      this.useBaseline = true,
      Key key}) : super(key: key) {
    assert(format != null);
    assert(color != null);
  }

  @override
  _AlignedTextState createState() => _AlignedTextState();
}

class _AlignedTextState extends State<AlignedText> {
  NumberFormat numberFormat;
  bool noDecimal;
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
    if (widget.alignment == ValueAlignment.decimal) {
      decimalIndex = widget.format.indexOf('.');
    } else {
      decimalIndex = -1;
    }
    noDecimal = decimalIndex == -1;
    RenderParagraph p;
    if (noDecimal) {
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
      p = getParagraph(100, widget.units);
      unitsHeight = p.getMaxIntrinsicHeight(double.infinity);
      unitsWidth = p.getMaxIntrinsicWidth(double.infinity);
    }
  }

  RenderParagraph getParagraph(double fontSize, String s) {
    final p = RenderParagraph(
        TextSpan(text: s, style: TextStyle(fontSize: fontSize)),
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
  final _AlignedTextState state;
  final AlignedText widget;
  final String value;

  _ValueBoxPainter(this.state)
      : this.widget = state.widget,
        this.value = state.widget.value;

  @override
  void paint(Canvas canvas, Size size) {
    final heightForUnits =
        (widget.units == null) ? 0 : (size.height * widget.unitsHeightFraction);
    final heightForValue = size.height - heightForUnits;
    final double fontSize = 100.0 *
        widget.scale *
        min(size.width / state.valueTotalWidth,
            heightForValue / state.valueHeight);
    final double vh = state.valueHeight * fontSize / 100.0; // Value height
    double vy; // y position of value
    if (widget.units == null) {
      vy = (size.height - vh) / 2;
    } else {
      final double unitsFontSize = 100.0 *
          min(size.width / state.unitsWidth,
              heightForUnits / state.unitsHeight);
      final double uh = state.unitsHeight * unitsFontSize / 100;
      final double available = size.height - (uh + vh);
      final space = min(available, uh / 2);
      // For the whitespace below the value, take no more than the height
      // of units.
      final double w = state.unitsWidth * unitsFontSize / 100;
      final double x = (size.width - w) / 2;
      vy = (size.height - (vh + space + uh)) / 2;
      final double y = vy + vh + space;
      final style = TextStyle(color: widget.color, fontSize: unitsFontSize);
      final span = TextSpan(text: widget.units, style: style);
      _paintText(x, y, span, canvas);
    }
    final double prefixW = state.prefixWidth * fontSize / 100.0;
    final double beforeW = state.valueBeforeWidth * fontSize / 100.0;
    final double afterW = state.valueAfterWidth * fontSize / 100.0;
    final double postfixW = state.postfixWidth * fontSize / 100.0;
    final double totalW = prefixW + beforeW + afterW + postfixW;
    final style = TextStyle(color: widget.color, fontSize: fontSize);
    double x = (size.width - totalW) / 2.0;
    if (widget.prefix != null) {
      final span = TextSpan(text: widget.prefix, style: style);
      _paintText(x, vy, span, canvas);
      x += prefixW;
    }
    if (value == null) {
      x += beforeW + afterW;
    } else {
      int decimalIndex = state.noDecimal ? -1 : value.indexOf('.');
      if (decimalIndex == -1) {
        decimalIndex = value.length;
      }
      {
        // units part:
        final span =
            TextSpan(text: value.substring(0, decimalIndex), style: style);
        final p = RenderParagraph(span,
            maxLines: 1,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.left);
        p.layout(BoxConstraints());
        final double beforeReal = p.getMaxIntrinsicWidth(double.infinity);
        switch(widget.alignment) {
          case ValueAlignment.left:
            _paintText(x, vy, span, canvas);
            break;
          case ValueAlignment.center:
            _paintText(x + (beforeW - beforeReal)/2.0, vy, span, canvas);
            break;
          case ValueAlignment.right:
            // Fall through
          case ValueAlignment.decimal:
          _paintText(x + beforeW - beforeReal, vy, span, canvas);
            break;
        }
        x += beforeW;
      }
      if (decimalIndex != value.length) {
        final span =
            TextSpan(text: value.substring(decimalIndex), style: style);
        _paintText(x, vy, span, canvas);
      }
      x += afterW;
    }
    if (widget.postfix != null) {
      final span = TextSpan(text: widget.postfix, style: style);
      _paintText(x, vy, span, canvas);
    }
  }

  void _paintText(double x, double y, TextSpan span, Canvas canvas) {
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
