import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui';
import 'dart:math';
import 'decimal_aligned_text.dart';
import 'data_types.dart';
import 'fitted_text.dart';

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

class ValueBox extends StatelessWidget {
  final String value; // may be null
  final String label;
  final double labelHeightFactor;
  final String format;
  final Color color;
  final String units;
  final String prefix; // String before the value; may be null
  final String postfix; // String after the value; may be null
  final ValueAlignment alignment;
  static final labelStyle = TextStyle(color: Colors.grey[400]);

  ValueBox(
      {@required this.value,
      @required this.label,
      this.labelHeightFactor = 0.28,
      @required this.format,
      @required this.color,
      this.units,
      this.prefix,
      this.postfix,
      this.alignment = ValueAlignment.decimal,
      Key key})
      : super(key: key) {
    assert(label != null);
    assert(labelHeightFactor != null);
    assert(format != null);
    assert(color != null);
  }

  @override
  Widget build(BuildContext context) {
    final int labelSpaceFlex =
        max(1, min(30, (100 * labelHeightFactor / 1.5).round()));
    return Container(
        padding: EdgeInsets.all(2.0),
        constraints: BoxConstraints.expand(),
        child: Stack(
          children: <Widget>[
            FractionallySizedBox(
                widthFactor: 1.0,
                heightFactor: labelHeightFactor,
                child: FittedText(label, key: key, style: labelStyle)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: labelSpaceFlex, child: Container()),
                Expanded(
                  flex: 100 - labelSpaceFlex,
                  child: AlignedText(
                      key: key,
                      alignment: alignment,
                      value: value,
                      prefix: prefix,
                      postfix: postfix,
                      units: units,
                      unitsHeightFraction:
                          0.85 * labelHeightFactor / (1 - labelHeightFactor),
                      format: format,
                      color: color),
                )
              ],
            ),
          ],
        ));
  }
}
