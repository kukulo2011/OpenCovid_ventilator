import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:quiver/core.dart' show hash3;
import 'dart:ui' show Color;
import 'package:intl/intl.dart' show NumberFormat;
import 'value_box.dart' as ui;
import 'rolling_chart.dart' as ui;
import 'read_device.dart' show ChartData;
import 'graphs_screen.dart' show HistoricalData;
import 'deques.dart';
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
  final String name;
  final List<Screen> screens;

  BreezyConfiguration(
      {@required this.name, @required this.feed, @required this.screens});

  static BreezyConfiguration defaultConfig = _createDefault();

  static BreezyConfiguration _createDefault() {
    final mapper = _DequeIndexMapper();
    final screens = Screen.defaultScreens(mapper);
    return BreezyConfiguration(
        name: 'default', screens: screens, feed: DataFeed.defaultFeed(mapper));
  }

  Map<String, Object> toJson() {
    return {
      'name': name,
      'feed': feed.toJson(),
      'screens': screens.map((s) => s.toJson()).toList(growable: false)
    };
  }
}

/// A little data class to identify a deque
class _DequeSelector {
  final bool isRolling;
  final double timeSpan;
  final int maxNumValues;

  _DequeSelector(this.isRolling, this.timeSpan, this.maxNumValues);

  @override
  bool operator ==(Object o) =>
      o is _DequeSelector &&
      isRolling == o.isRolling &&
      timeSpan == o.timeSpan &&
      maxNumValues == o.maxNumValues;

  @override
  int get hashCode => hash3(isRolling, timeSpan, maxNumValues);
}

/// A class to build up a deque index map, to map the characteristics
/// of needed deques to their eventual indices in HistoricalData.
class _DequeIndexMapper {
  bool screensInitialized = false;
  final dequeIndexMap = Map<_DequeSelector, int>();

  int getDequeIndex(bool isRolling, double timeSpan, int maxNumValues) {
    final sel = _DequeSelector(isRolling, timeSpan, maxNumValues);
    final result = dequeIndexMap[sel];
    if (result != null) {
      return result;
    } else {
      final i = dequeIndexMap.length;
      dequeIndexMap[sel] = i;
      return i;
    }
  }
}

class DataFeed {
  final List<ChartedValue> chartedValues;
  final List<FormattedValue> displayedValues;
  final Map<_DequeSelector, int> dequeIndexMap;
  final bool checksumIsOptional;

  int get totalNumValues => displayedValues.length + chartedValues.length + 4;
  // Thats one for "breezy", one for the version #, one for time, and
  // one for the checksum

  DataFeed(
      {@required this.chartedValues,
      @required this.displayedValues,
      @required this.dequeIndexMap,
      @required this.checksumIsOptional});

  static DataFeed defaultFeed(_DequeIndexMapper mapper) {
    assert(mapper.screensInitialized);
    return DataFeed(
        checksumIsOptional: true,
        chartedValues: [
          ChartedValue(-10, 50),
          ChartedValue(-100, 100),
          ChartedValue(0, 800)
        ],
        displayedValues: [
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
        ],
        dequeIndexMap: mapper.dequeIndexMap);
  }

  Map<String, Object> toJson() {
    return null; // TODO
  }

  List<WindowedData<ChartData>> createDeques() {
    final result = List<WindowedData<ChartData>>(dequeIndexMap.length);
    dequeIndexMap.forEach((sel, i) {
      if (sel.isRolling) {
        result[i] = RollingDeque<ChartData>(sel.maxNumValues + 1, sel.timeSpan,
            sel.timeSpan / 20, (double time) => ChartData.dummy(time));
      } else {
        result[i] = SlidingDeque<ChartData>(sel.maxNumValues, sel.timeSpan);
      }
    });
    return result;
  }
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
      return '1:' + format.format(1 / value);
    }
  }
}

class ChartedValue {
  final double minValue;
  final double maxValue;

  const ChartedValue(this.minValue, this.maxValue);
}

class Screen {
  static List<Screen> defaultScreens(_DequeIndexMapper mapper) {
    assert(!mapper.screensInitialized);
    mapper.screensInitialized = true;
    final result = [_defaultScreen()];
    for (final s in result) {
      s.init(mapper);
    }
    return result;
  }

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

  void init(_DequeIndexMapper mapper) {
    portrait.init(null, mapper);
    if (portrait != landscape) {
      landscape.init(null, mapper);
    }
  }

  Map<String, Object> toJson() {
    return null; // TODO
  }
}

abstract class ScreenValue {
  /// Defaults to 1.  Ignored for root node.
  final int flex;
  bool hasParent = true;

  ScreenValue(this.flex);

  /// [parent] is the row or column that contains us, or null if we're
  @mustCallSuper
  void init(ScreenContainer parent, _DequeIndexMapper mapper) {
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

  @override
  void init(ScreenContainer parent, _DequeIndexMapper mapper) {
    super.init(parent, mapper);
    for (final c in content) {
      c.init(this, mapper);
    }
  }

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
  void init(ScreenContainer parent, _DequeIndexMapper mapper) {
    super.init(parent, mapper);
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
  void init(ScreenContainer parent, _DequeIndexMapper mapper) {
    super.init(parent, mapper);
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
  final double labelHeightFactor;
  final String units;
  final String format;
  final Color color;
  final String prefix;
  final String postfix;
  ValueBox(
      {int flex = 1,
      @required this.valueIndex,
      @required this.label,
      @required this.labelHeightFactor,
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
        labelHeightFactor: labelHeightFactor,
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
      labelHeightFactor: labelHeightFactor,
      units: units,
      format: format,
      color: color,
      prefix: prefix,
      postfix: postfix);
}

class TimeChart extends ScreenValue
    implements ui.TimeChartSelector<ChartData> {
  final bool rolling;
  final double minValue;
  final double maxValue;
  final double timeSpan;
  final int maxNumValues;
  final int displayedTimeTicks;
  final charts.Color color;
  final String label;
  final double labelHeightFactor;
  int _dequeIndex = -1;
  final int valueIndex;

  TimeChart(
      {int flex = 1,
      this.rolling = true,
      @required this.minValue,
      @required this.maxValue,
      @required this.timeSpan,
      @required this.maxNumValues,
      @required this.displayedTimeTicks,
      @required this.color,
      @required this.label,
      @required this.labelHeightFactor,
      @required this.valueIndex})
      : super(flex);

  /// Convenience method for creating the same ValueBox with a different
  /// flex.  This is helpful for having different portrait/landscape
  /// layouts.
  TimeChart withFlex(int newFlex) => TimeChart(
      flex: newFlex,
      rolling: rolling,
      minValue: minValue,
      maxValue: maxValue,
      timeSpan: timeSpan,
      maxNumValues: maxNumValues,
      displayedTimeTicks: displayedTimeTicks,
      color: color,
      label: label,
      labelHeightFactor: labelHeightFactor,
      valueIndex: valueIndex);

  @override
  void init(ScreenContainer parent, _DequeIndexMapper mapper) {
    super.init(parent, mapper);
    _dequeIndex = mapper.getDequeIndex(rolling, timeSpan, maxNumValues);
  }

  @override
  material.Widget build(HistoricalData data) {
    final WindowedData<ChartData> deque = data.getDeque(_dequeIndex);
    assert(deque.windowSize == timeSpan);
    final tc = ui.TimeChart<ChartData>(
        selector: this,
        label: label,
        labelHeightFactor: labelHeightFactor,
        numTicks: displayedTimeTicks,
        minValue: minValue,
        maxValue: maxValue,
        graphColor: color,
        data: deque);
    return _wrapIfNeeded(tc);
  }

  @override
  double getValue(ChartData data) => data.values?.elementAt(valueIndex);
}

Screen _defaultScreen() {
  final labelHeight = 0.24;
  final chartedValues = [
    TimeChart(
        valueIndex: 0,
        color: charts.MaterialPalette.deepOrange.shadeDefault.lighter,
        displayedTimeTicks: 11,
        timeSpan: 10,
        maxNumValues: 500,
        label: 'PRESSURE cmH2O',
        labelHeightFactor: labelHeight / 2,
        minValue: -10.0,
        maxValue: 50.0),
    TimeChart(
        valueIndex: 1,
        color: charts.MaterialPalette.green.shadeDefault.lighter,
        displayedTimeTicks: 11,
        timeSpan: 10,
        maxNumValues: 500,
        label: 'FLOW l/min',
        labelHeightFactor: labelHeight / 2,
        minValue: -100.0,
        maxValue: 100.0),
    TimeChart(
        valueIndex: 2,
        color: charts.MaterialPalette.blue.shadeDefault.lighter,
        displayedTimeTicks: 11,
        timeSpan: 10,
        maxNumValues: 500,
        label: 'VOLUME ml',
        labelHeightFactor: labelHeight / 2,
        minValue: 0.0,
        maxValue: 800.0),
  ];

  final displayedValues = [
    ValueBox(
        valueIndex: 0,
        label: 'Ppeak',
        labelHeightFactor: labelHeight / 2,
        units: 'cmH2O',
        format: '##.#',
        color: material.Colors.orange.shade300),
    ValueBox(
        valueIndex: 1,
        label: 'Pmean',
        labelHeightFactor: labelHeight,
        units: 'cmH2O',
        format: '##.#',
        color: material.Colors.orange.shade300),
    ValueBox(
        valueIndex: 2,
        label: 'PEEP',
        units: 'cmH2O',
        labelHeightFactor: labelHeight,
        format: '##.#',
        color: material.Colors.orange.shade300),
    ValueBox(
        valueIndex: 3,
        label: 'RR',
        labelHeightFactor: labelHeight,
        units: 'b/min',
        format: '##.#',
        color: material.Colors.lightGreen),
    ValueBox(
        valueIndex: 4,
        label: 'O2',
        labelHeightFactor: labelHeight,
        units: null,
        format: '1##',
        color: material.Colors.lightGreen,
        postfix: '%'),
    ValueBox(
        valueIndex: 5,
        label: 'Ti',
        labelHeightFactor: labelHeight,
        units: 's',
        format: '##.##',
        color: material.Colors.lightGreen),
    ValueBox(
        valueIndex: 6,
        label: 'I:E',
        labelHeightFactor: labelHeight,
        units: null,
        format: '1:#,#', // ',' instead of '.' so it doesn't align
        color: material.Colors.lightGreen),
    ValueBox(
        valueIndex: 7,
        label: 'MVi',
        labelHeightFactor: labelHeight,
        units: 'l/min',
        format: '##.#',
        color: material.Colors.lightBlue),
    ValueBox(
        valueIndex: 8,
        label: 'MVe',
        labelHeightFactor: labelHeight,
        units: 'l/min',
        format: '##.#',
        color: material.Colors.lightBlue),
    ValueBox(
        valueIndex: 9,
        label: 'VTi',
        labelHeightFactor: labelHeight,
        units: null,
        format: '####',
        color: material.Colors.lightBlue),
    ValueBox(
        valueIndex: 10,
        label: 'VTe',
        labelHeightFactor: labelHeight,
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
