import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'dart:ui' show Color;
import 'package:intl/intl.dart' show NumberFormat;
import 'value_box.dart' as ui;
import 'rolling_chart.dart' as ui;
import 'read_device.dart' show DeviceData, ChartData;
import 'graphs_screen.dart' show HistoricalData;
import 'package:charts_flutter/flutter.dart' as charts;

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

class BreezyConfiguration {
  final DataFeed feed;
  List<Screen> get screens => Screen.defaultScreens;

  BreezyConfiguration({@required this.feed});

  static BreezyConfiguration defaultConfig =
      BreezyConfiguration(feed: DataFeed.defaultFeed);
}

class DataFeed {
  final List<ChartedValue> chartedValues;
  final List<FormattedValue> displayedValues;
  final bool checksumIsOptional;

  int get totalNumValues => displayedValues.length + chartedValues.length + 4;
  // Thats one for "breezy", one for the version #, one for time, and
  // one for the checksum

  const DataFeed(
      {@required this.chartedValues,
      @required this.displayedValues,
      @required this.checksumIsOptional});

  static DataFeed defaultFeed =
      DataFeed(checksumIsOptional: true, chartedValues: [
    ChartedValue(-10, 50),
    ChartedValue(-100, 100),
    ChartedValue(0, 800)
  ], displayedValues: [
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('#0.0', 0, 99.9),
    FormattedValue('##0', 0, 100.0),
    FormattedValue('#0.0', 0, 99.9),
    RatioValue('0.0', 0.5, 2),
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

  String formatValue(double value) => format.format(value);
}

class RatioValue extends FormattedValue {
  RatioValue(String format, double minValue, double maxValue)
      : super(format, minValue, maxValue);
  String formatValue(double value) {
    if (value >= 1.0) {
      return format.format(value) + ':1';
    } else {
      return '1:' + format.format(1/value);
    }
  }

}

class ChartedValue {
  final double minValue;
  final double maxValue;

  const ChartedValue(this.minValue, this.maxValue);
}

class Screen {
  static List<Screen> get defaultScreens => [_defaultScreen()]; // TODO

  final String name;
  final ScreenContainer portrait;
  final ScreenContainer landscape;

  Screen(
      {@required this.name,
      @required this.portrait,
      @required this.landscape}) {
    assert(name != null);
    assert(portrait != null);
    assert(landscape != null);
  }

  void init() {
    portrait.init(null);
    if (portrait != landscape) {
      landscape.init(null);
    }
  }
}

abstract class ScreenValue {
  /// Defaults to 1.  Ignored for root node.
  final int flex;
  bool hasParent = true;

  ScreenValue(this.flex);

  /// [parent] is the row or column that contains us, or null if we're
  @mustCallSuper
  void init(ScreenContainer parent) {
    hasParent = parent != null;
  }

  /// at the top of the tree.  [data] is the data to be rendered.
  material.Widget build(HistoricalData data);

  material.Widget _wrapIfNeeded(material.Widget w) {
    if (hasParent) {
      return material.Expanded(flex: flex, child: w);
    } else {
      return w;
    }
  }
}

class Spacer extends ScreenValue {
  Spacer(int flex) : super(flex);

  @override
  material.Widget build(HistoricalData data) {
    return material.Spacer(flex: flex);
  }
}

class Label extends ScreenValue {
  final String text;
  final Color color;

  Label({@required int flex, @required this.text, @required this.color})
      : super(flex);

  material.Widget build(HistoricalData data) => _wrapIfNeeded(
      material.Text(text, style: material.TextStyle(color: color)));
}

abstract class ScreenContainer extends ScreenValue {
  final List<ScreenValue> content;
  ScreenContainer({@required int flex, @required this.content}) : super(flex);

  List<material.Widget> _buildChildren(HistoricalData data) {
    final result = List<material.Widget>(content.length);
    for (int i = 0; i < content.length; i++) {
      result[i] = content[i].build(data);
    }
    return result;
  }
}

class ScreenColumn extends ScreenContainer {
  ScreenColumn({int flex = 1, @required List<ScreenValue> content})
      : super(flex: flex, content: content);

  @override
  void init(ScreenContainer parent) {
    super.init(parent);
    if (parent is ScreenColumn) {
      throw Exception("A column can't contain another column");
    }
  }

  material.Widget build(HistoricalData data) =>
      _wrapIfNeeded(material.Column(children: _buildChildren(data)));
}

class ScreenRow extends ScreenContainer {
  ScreenRow({int flex = 1, @required List<ScreenValue> content})
      : super(flex: flex, content: content);

  @override
  void init(ScreenContainer parent) {
    super.init(parent);
    if (parent is ScreenRow) {
      throw Exception("A row can't contain another row");
    }
  }

  material.Widget build(HistoricalData data) =>
      _wrapIfNeeded(material.Row(children: _buildChildren(data)));
}

class ValueBox extends ScreenValue {
  final int valueIndex;
  final String label;
  final String units;
  final String format;
  final Color color;
  final String prefix;
  final String postfix;
  ValueBox(
      {int flex = 1,
      @required this.valueIndex,
      @required this.label,
      @required this.units,
      @required this.format,
      @required this.color,
      this.prefix,
      this.postfix})
      : super(flex);

  @override
  material.Widget build(HistoricalData data) {
    final vb = ui.ValueBox(
        value: data.current?.displayedValues?.elementAt(valueIndex),
        label: label,
        format: format,
        color: color,
        units: units,
        prefix: prefix,
        postfix: postfix);
    return _wrapIfNeeded(vb);
  }

  /// Convenience method for creating the same ValueBox with a different
  /// flex.  This is helpful for having different portrait/landscape
  /// layouts.
  ValueBox withFlex(int newFlex) => ValueBox(
      flex: newFlex,
      valueIndex: valueIndex,
      label: label,
      units: units,
      format: format,
      color: color,
      prefix: prefix,
      postfix: postfix);
}

class RollingChart extends ScreenValue
    implements ui.RollingChartSelector<ChartData> {
  final double minValue;
  final double maxValue;
  final int displayedTimeTicks;
  final charts.Color color;
  final String label;
  final int dequeIndex;
  final int valueIndex;

  RollingChart(
      {int flex = 1,
      @required this.minValue,
      @required this.maxValue,
      @required this.displayedTimeTicks,
      @required this.color,
      @required this.label,
      @required this.dequeIndex,
      @required this.valueIndex})
      : super(flex);

  /// Convenience method for creating the same ValueBox with a different
  /// flex.  This is helpful for having different portrait/landscape
  /// layouts.
  RollingChart withFlex(int newFlex) => RollingChart(
      flex: newFlex,
      minValue: minValue,
      maxValue: maxValue,
      displayedTimeTicks: displayedTimeTicks,
      color: color,
      label: label,
      dequeIndex: dequeIndex,
      valueIndex: valueIndex);

  @override
  material.Widget build(HistoricalData data) {
    final tc = ui.RollingChart<ChartData>(
        selector: this,
        label: label,
        numTicks: displayedTimeTicks,
        minValue: minValue,
        maxValue: maxValue,
        graphColor: color,
        windowSize: data.getWindowSize(dequeIndex),
        data: data.getWindow(dequeIndex));
    return _wrapIfNeeded(tc);
  }

  @override
  double getValue(ChartData data) => data.values?.elementAt(valueIndex);
}

Screen _defaultScreen() {
// By re-calculating this every time, we make development using
// hot reload easier
  final chartedValues = [
    RollingChart(
        dequeIndex: 0,
        valueIndex: 0,
        color: charts.MaterialPalette.deepOrange.shadeDefault.lighter,
        displayedTimeTicks: 11,
        label: 'PRESSURE cmH2O',
        minValue: -10.0,
        maxValue: 50.0),
    RollingChart(
        dequeIndex: 0,
        valueIndex: 1,
        color: charts.MaterialPalette.green.shadeDefault.lighter,
        displayedTimeTicks: 11,
        label: 'FLOW l/min',
        minValue: -100.0,
        maxValue: 100.0),
    RollingChart(
        dequeIndex: 0,
        valueIndex: 2,
        color: charts.MaterialPalette.blue.shadeDefault.lighter,
        displayedTimeTicks: 11,
        label: 'VOLUME ml',
        minValue: 0.0,
        maxValue: 800.0),
  ];

  final displayedValues = [
    ValueBox(
        valueIndex: 0,
        label: 'Ppeak',
        units: 'cmH2O',
        format: '##.#',
        color: material.Colors.orange.shade300),
    ValueBox(
        valueIndex: 1,
        label: 'Pmean',
        units: 'cmH2O',
        format: '##.#',
        color: material.Colors.orange.shade300),
    ValueBox(
        valueIndex: 2,
        label: 'PEEP',
        units: 'cmH2O',
        format: '##.#',
        color: material.Colors.orange.shade300),
    ValueBox(
        valueIndex: 3,
        label: 'RR',
        units: 'b/min',
        format: '##.#',
        color: material.Colors.lightGreen),
    ValueBox(
        valueIndex: 4,
        label: 'O2',
        units: null,
        format: '1##',
        color: material.Colors.lightGreen,
        postfix: '%'),
    ValueBox(
        valueIndex: 5,
        label: 'Ti',
        units: 's',
        format: '##.##',
        color: material.Colors.lightGreen),
    ValueBox(
        valueIndex: 6,
        label: 'I:E',
        units: null,
        format: '1:#,#', // ',' instead of '.' so it doesn't align
        color: material.Colors.lightGreen),
    ValueBox(
        valueIndex: 7,
        label: 'MVi',
        units: 'l/min',
        format: '##.#',
        color: material.Colors.lightBlue),
    ValueBox(
        valueIndex: 8,
        label: 'MVe',
        units: 'l/min',
        format: '##.#',
        color: material.Colors.lightBlue),
    ValueBox(
        valueIndex: 9,
        label: 'VTi',
        units: null,
        format: '####',
        color: material.Colors.lightBlue),
    ValueBox(
        valueIndex: 10,
        label: 'VTe',
        units: 'ml',
        format: '####',
        color: material.Colors.lightBlue)
  ];

  final landscape = ScreenRow(content: [
    ScreenColumn(flex: 8, content: [
      chartedValues[0],
      chartedValues[1],
      chartedValues[2],
    ]),
    ScreenColumn(flex: 4, content: [
      ScreenRow(content: [
        displayedValues[0].withFlex(4),
        ScreenColumn(flex: 3, content: [displayedValues[1], displayedValues[2]])
      ]),
      ScreenRow(content: [
        ScreenColumn(
            flex: 4, content: [displayedValues[3], displayedValues[4]]),
        ScreenColumn(flex: 3, content: [displayedValues[5], displayedValues[6]])
      ]),
      ScreenRow(content: [
        ScreenColumn(
            flex: 4, content: [displayedValues[7], displayedValues[8]]),
        ScreenColumn(
            flex: 3, content: [displayedValues[9], displayedValues[10]])
      ]),
    ])
  ]);

  final portrait = ScreenRow(content: [
    ScreenColumn(content: [
      chartedValues[0].withFlex(2),
      chartedValues[1].withFlex(2),
      chartedValues[2].withFlex(2),
      ScreenRow(flex: 2, content: [
        displayedValues[0],
        ScreenColumn(content: [displayedValues[1], displayedValues[2]]),
        ScreenColumn(content: [displayedValues[7], displayedValues[8]]),
      ]),
      ScreenRow(flex: 2, content: [
        ScreenColumn(content: [displayedValues[3], displayedValues[4]]),
        ScreenColumn(content: [displayedValues[5], displayedValues[6]]),
        ScreenColumn(content: [displayedValues[9], displayedValues[10]])
      ]),
    ])
  ]);

  return Screen(name: 'default', portrait: portrait, landscape: landscape);
}
