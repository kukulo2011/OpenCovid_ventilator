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
    final feed = _defaultFeed();
    final screens = Screen.defaultScreens(feed);
    return BreezyConfiguration(name: 'default', screens: screens, feed: feed);
  }

  Map<String, Object> toJson() {
    return {
      'type': 'BreezyConfiguration',
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
  final ValueBox displayer;

  FormattedValue(String format, this.minValue, this.maxValue, this.displayer)
      : this.format = NumberFormat(format);

  String formatValue(double value) => format.format(value);
}

class RatioValue extends FormattedValue {
  RatioValue(
      String format, double minValue, double maxValue, ValueBox displayer)
      : super(format, minValue, maxValue, displayer);
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
  final TimeChart displayer;

  const ChartedValue(this.minValue, this.maxValue, this.displayer);
}

class Screen {
  static List<Screen> defaultScreens(DataFeed feed) {
    final result = [_defaultScreen(feed)];
    for (final s in result) {
      s.init();
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

  void init() {
    portrait.init(null);
    if (portrait != landscape) {
      landscape.init(null);
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

  @override
  void init(ScreenContainer parent) {
    super.init(parent);
    for (final c in content) {
      c.init(this);
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

class DataWidget extends ScreenValue {
  final DataDisplayer displayer;

  DataWidget({int flex = 1, @required this.displayer}) : super(flex);

  @override
  material.Widget build(HistoricalData data) {
    return _wrapIfNeeded(displayer.build(data));
  }
}

abstract class DataDisplayer {
  material.Widget build(HistoricalData data);
}

class ValueBox implements DataDisplayer {
  final int valueIndex;
  final String label;
  final double labelHeightFactor;
  final String units;
  final String format;
  final Color color;
  final String prefix;
  final String postfix;
  ValueBox(
      {@required this.valueIndex,
      @required this.label,
      @required this.labelHeightFactor,
      @required this.units,
      @required this.format,
      @required this.color,
      this.prefix,
      this.postfix});

  @override
  material.Widget build(HistoricalData data) => ui.ValueBox(
      value: data.current?.displayedValues?.elementAt(valueIndex),
      label: label,
      labelHeightFactor: labelHeightFactor,
      format: format,
      color: color,
      units: units,
      prefix: prefix,
      postfix: postfix);
}

class TimeChart implements DataDisplayer, ui.TimeChartSelector<ChartData> {
  final bool rolling;
  final double minValue;
  final double maxValue;
  final double timeSpan;
  final int maxNumValues;
  final int displayedTimeTicks;
  final charts.Color color;
  final String label;
  final double labelHeightFactor;
  final int _dequeIndex;
  final int valueIndex;

  TimeChart(
      {this.rolling = true,
      @required this.minValue,
      @required this.maxValue,
      @required this.timeSpan,
      @required this.maxNumValues,
      @required this.displayedTimeTicks,
      @required this.color,
      @required this.label,
      @required this.labelHeightFactor,
      @required this.valueIndex,
      @required _DequeIndexMapper mapper})
      : _dequeIndex = mapper.getDequeIndex(rolling, timeSpan, maxNumValues);

  material.Widget build(HistoricalData data) {
    final WindowedData<ChartData> deque = data.getDeque(_dequeIndex);
    assert(deque.windowSize == timeSpan);
    return ui.TimeChart<ChartData>(
        selector: this,
        label: label,
        labelHeightFactor: labelHeightFactor,
        numTicks: displayedTimeTicks,
        minValue: minValue,
        maxValue: maxValue,
        graphColor: color,
        data: deque);
  }

  @override
  double getValue(ChartData data) => data.values?.elementAt(valueIndex);
}

DataFeed _defaultFeed() {
  final mapper = _DequeIndexMapper();
  final labelHeight = 0.24;
  return DataFeed(
      checksumIsOptional: true,
      chartedValues: [
        ChartedValue(
          -10,
          50,
          TimeChart(
              valueIndex: 0,
              color: charts.MaterialPalette.deepOrange.shadeDefault.lighter,
              displayedTimeTicks: 11,
              timeSpan: 10,
              maxNumValues: 500,
              label: 'PRESSURE cmH2O',
              labelHeightFactor: labelHeight / 2,
              minValue: -10.0,
              maxValue: 50.0,
              mapper: mapper),
        ),
        ChartedValue(
          -100,
          100,
          TimeChart(
              valueIndex: 1,
              color: charts.MaterialPalette.green.shadeDefault.lighter,
              displayedTimeTicks: 11,
              timeSpan: 10,
              maxNumValues: 500,
              label: 'FLOW l/min',
              labelHeightFactor: labelHeight / 2,
              minValue: -100.0,
              maxValue: 100.0,
              mapper: mapper),
        ),
        ChartedValue(
          0,
          800,
          TimeChart(
              valueIndex: 2,
              color: charts.MaterialPalette.blue.shadeDefault.lighter,
              displayedTimeTicks: 11,
              timeSpan: 10,
              maxNumValues: 500,
              label: 'VOLUME ml',
              labelHeightFactor: labelHeight / 2,
              minValue: 0.0,
              maxValue: 800.0,
              mapper: mapper),
        )
      ],
      displayedValues: [
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 0,
              label: 'Ppeak',
              labelHeightFactor: labelHeight / 2,
              units: 'cmH2O',
              format: '##.#',
              color: material.Colors.orange.shade300),
        ),
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 1,
              label: 'Pmean',
              labelHeightFactor: labelHeight,
              units: 'cmH2O',
              format: '##.#',
              color: material.Colors.orange.shade300),
        ),
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 2,
              label: 'PEEP',
              units: 'cmH2O',
              labelHeightFactor: labelHeight,
              format: '##.#',
              color: material.Colors.orange.shade300),
        ),
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 3,
              label: 'RR',
              labelHeightFactor: labelHeight,
              units: 'b/min',
              format: '##.#',
              color: material.Colors.lightGreen),
        ),
        FormattedValue(
          '##0',
          0,
          100.0,
          ValueBox(
              valueIndex: 4,
              label: 'O2',
              labelHeightFactor: labelHeight,
              units: null,
              format: '1##',
              color: material.Colors.lightGreen,
              postfix: '%'),
        ),
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 5,
              label: 'Ti',
              labelHeightFactor: labelHeight,
              units: 's',
              format: '##.##',
              color: material.Colors.lightGreen),
        ),
        RatioValue(
          '0.0',
          0.5,
          2,
          ValueBox(
              valueIndex: 6,
              label: 'I:E',
              labelHeightFactor: labelHeight,
              units: null,
              format: '1:#,#', // ',' instead of '.' so it doesn't align
              color: material.Colors.lightGreen),
        ),
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 7,
              label: 'MVi',
              labelHeightFactor: labelHeight,
              units: 'l/min',
              format: '##.#',
              color: material.Colors.lightBlue),
        ),
        FormattedValue(
          '#0.0',
          0,
          99.9,
          ValueBox(
              valueIndex: 8,
              label: 'MVe',
              labelHeightFactor: labelHeight,
              units: 'l/min',
              format: '##.#',
              color: material.Colors.lightBlue),
        ),
        FormattedValue(
          '###0',
          0,
          9999,
          ValueBox(
              valueIndex: 9,
              label: 'VTi',
              labelHeightFactor: labelHeight,
              units: null,
              format: '####',
              color: material.Colors.lightBlue),
        ),
        FormattedValue(
            '###0',
            0,
            9999,
            ValueBox(
                valueIndex: 10,
                label: 'VTe',
                labelHeightFactor: labelHeight,
                units: 'ml',
                format: '####',
                color: material.Colors.lightBlue))
      ],
      dequeIndexMap: mapper.dequeIndexMap);
}

Screen _defaultScreen(DataFeed feed) {
  final landscape = ScreenRow(content: [
    ScreenColumn(flex: 8, content: [
      DataWidget(displayer: feed.chartedValues[0].displayer),
      DataWidget(displayer: feed.chartedValues[1].displayer),
      DataWidget(displayer: feed.chartedValues[2].displayer),
    ]),
    ScreenColumn(flex: 4, content: [
      ScreenRow(content: [
        DataWidget(flex: 4, displayer: feed.displayedValues[0].displayer),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[1].displayer),
          DataWidget(displayer: feed.displayedValues[2].displayer),
        ])
      ]),
      ScreenRow(content: [
        ScreenColumn(flex: 4, content: [
          DataWidget(displayer: feed.displayedValues[3].displayer),
          DataWidget(displayer: feed.displayedValues[4].displayer),
        ]),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[5].displayer),
          DataWidget(displayer: feed.displayedValues[6].displayer),
        ])
      ]),
      ScreenRow(content: [
        ScreenColumn(flex: 4, content: [
          DataWidget(displayer: feed.displayedValues[7].displayer),
          DataWidget(displayer: feed.displayedValues[8].displayer),
        ]),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[9].displayer),
          DataWidget(displayer: feed.displayedValues[10].displayer),
        ])
      ]),
    ])
  ]);

  final portrait = ScreenRow(content: [
    ScreenColumn(content: [
      DataWidget(flex: 2, displayer: feed.chartedValues[0].displayer),
      DataWidget(flex: 2, displayer: feed.chartedValues[1].displayer),
      DataWidget(flex: 2, displayer: feed.chartedValues[2].displayer),
      ScreenRow(flex: 2, content: [
        DataWidget(displayer: feed.displayedValues[0].displayer),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[1].displayer),
          DataWidget(displayer: feed.displayedValues[2].displayer),
        ]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[7].displayer),
          DataWidget(displayer: feed.displayedValues[8].displayer),
        ]),
      ]),
      ScreenRow(flex: 2, content: [
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[3].displayer),
          DataWidget(displayer: feed.displayedValues[4].displayer),
        ]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[5].displayer),
          DataWidget(displayer: feed.displayedValues[6].displayer),
        ]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[9].displayer),
          DataWidget(displayer: feed.displayedValues[10].displayer),
        ])
      ]),
    ])
  ]);

  return Screen(name: 'default', portrait: portrait, landscape: landscape);
}
