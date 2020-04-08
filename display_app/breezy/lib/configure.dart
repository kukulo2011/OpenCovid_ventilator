import 'package:flutter/foundation.dart';
import 'dart:ui' show Color;
import 'package:intl/intl.dart' show NumberFormat;
import 'value_box.dart' as ui;
import 'rolling_chart.dart' as ui;
import 'read_device.dart' show DeviceData;

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

// TODO:  Receive .breezy config files
//    cf. https://pub.dev/packages/receive_sharing_intent,
//        https://stackoverflow.com/questions/4799576/register-a-new-file-type-in-android#4838863

class DataFeed {
  final List<ChartedValue> chartedValues;
  final List<FormattedValue> displayedValues;

  int get totalNumValues => displayedValues.length + chartedValues.length + 4;
  // Thats one for "breezy", one for the version #, one for time, and
  // one for the checksum

  const DataFeed(this.chartedValues, this.displayedValues);

  static DataFeed defaultFeed = DataFeed([
    ChartedValue(-10, 50),
    ChartedValue(-100, 100),
    ChartedValue(0, 800)
  ], [
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('##0', 0, 100.0),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('0.0', 0, 9.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('###0', 0, 9999),
    FormattedValue('###0', 0, 9999)
  ]);
}

class FormattedValue {
  final NumberFormat format;
  final double minValue;
  final double maxValue;

  FormattedValue(String format, this.minValue, this.maxValue)
      : this.format = NumberFormat(format);
}

class ChartedValue {
  final double minValue;
  final double maxValue;

  const ChartedValue(this.minValue, this.maxValue);
}

class ValueBox {
  final int index;
  final String label;
  final String units;
  final String format;
  final Color color;
  final String prefix;
  final String postfix;
  ValueBox(
    this.index, this.label, this.units, this.format, this.color,
    {this.prefix, this.postfix});

  ui.ValueBox build(DeviceData data) {
    return ui.ValueBox(
      value: data?.displayedValues?.elementAt(index),
      label: label,
      format: format,
      color: color,
      units: units,
      prefix: prefix,
      postfix: postfix);
  }
}


class BreezyConfiguration {
  final DataFeed feed;

  BreezyConfiguration({@required this.feed});

  static BreezyConfiguration defaultConfig =
      BreezyConfiguration(feed: DataFeed.defaultFeed);
}
