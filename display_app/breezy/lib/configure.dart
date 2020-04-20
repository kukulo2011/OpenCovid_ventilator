import 'dart:convert';
import 'dart:math' show min;
import 'dart:io' show IOSink, gzip;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:archive/archive_io.dart' show Crc32;
import 'package:quiver/core.dart' show hash3;
import 'dart:ui' show Color;
import 'package:intl/intl.dart' show NumberFormat;
import 'value_box.dart' as ui;
import 'main.dart' show toHex;
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

//    cf. https://pub.dev/packages/receive_sharing_intent,
//        https://stackoverflow.com/questions/4799576/register-a-new-file-type-in-android#4838863

abstract class BreezyConfiguration {
  final DataFeed feed;
  final String name;
  final List<Screen> screens;
  Future<List<String>> getSampleLog(AssetBundle bundle);
  Map<String, int> _screenNumByName;

  BreezyConfiguration(
      {@required this.name, @required this.feed, @required this.screens}) {
    assert(name != null);
    assert(feed != null);
    assert(screens != null);
  }

  static BreezyConfiguration defaultConfig = _createDefault();

  static BreezyConfiguration _createDefault() {
    final feed = _defaultFeed();
    final screens = Screen.defaultScreens(feed);
    return _DefaultBreezyConfiguration(
        name: 'default', screens: screens, feed: feed);
  }

  int getScreenNum(String name) {
    if (_screenNumByName == null) {
      _screenNumByName = Map<String, int>();
      for (int i = 0; i < screens.length; i++) {
        _screenNumByName[screens[i].name] = i;
      }
    }
    return _screenNumByName[name];
  }

  /// Ouput this configuration as a map, suitable to be written out
  /// with JsonEncoder.  This isn't truly needed in production, but it's the
  /// easiest way to make a sample JSON file from the default config.
  /// It's hooked into the server socket implementation.
  Future<Map<String, Object>> toJson(AssetBundle bundle) async {
    return {
      'type': 'BreezyConfiguration',
      'version': 1,
      'name': name,
      'feed': feed.toJson(),
      'screens': screens.map((s) => s.toJson()).toList(growable: false),
      'sampleLog': await getSampleLog(bundle)
    };
  }

  /// Throws various kinds of exceptions on malformed input
  static BreezyConfiguration fromJson(Map<Object, Object> jsonSrc) {
    final json = _JsonHelper(jsonSrc);
    json.expect('type', 'BreezyConfiguration');
    json.expect('version', 1);
    return _JsonBreezyConfiguration(
        name: json['name'] as String,
        feed: json.decode('feed', DataFeed._fromJson),
        screens: json.decodeList('screens', Screen._fromJson),
        sampleLog: json.getList<String>('sampleLog'));
  }

  Future<void> writeJson(IOSink sink, AssetBundle bundle) async {
    sink.writeln(JsonEncoder.withIndent('  ').convert(await toJson(bundle)));
    sink.writeln('');
  }

  /// Write out a compact representation, consisting of base64-encoded
  /// gzipped JSON, plus a Crc32 checksum.
  Future<void> writeCompact(IOSink sink, AssetBundle bundle) async {
    String str = JsonEncoder().convert(await toJson(bundle));
    List<int> bytes = utf8.encode(str);
    str = null;
    bytes = gzip.encoder.convert(bytes);
    int checksum = (Crc32()..add(bytes)).hash;
    sink.writeln('read-config-compact:${toHex(checksum, 8)}');
    str = base64.encoder.convert(bytes);
    bytes = null;
    for (int i = 0; i < str.length; i += 72) {
      int end = min(i + 72, str.length);
      sink.writeln(str.substring(i, end));
    }
  }
}

class BreezyConfigurationJsonReader {

  bool get done => _done;
  bool _done = false;
  final _source = StringBuffer();
  final bool compact;
  final int checksum;

  BreezyConfigurationJsonReader({this.compact = false, this.checksum});

  void acceptLine(String line) {
    assert(!_done);
    if (line == '') {
      _done = true;
      return;
    }
    _source.writeln(line);
  }

  BreezyConfiguration getResult() {
    assert(_done);
    String src;
    if (compact) {
      List<int> bytes = base64Decode(_source.toString());
      _source.clear();
      int c = (Crc32()..add(bytes)).hash;
      if (checksum != c) {
        throw ArgumentError('Crc32 checksum is $c, not expected $checksum');
      }
      bytes = gzip.decode(bytes);
      src = utf8.decode(bytes);
    } else {
      assert(checksum == null);
      src = _source.toString();
      _source.clear();
    }
    final json = jsonDecode(src) as Map<Object, Object>;
    _done = false;
    src = null;
    return BreezyConfiguration.fromJson(json);
  }
}

class _JsonBreezyConfiguration extends BreezyConfiguration {
  final List<String> _sampleLog;

  _JsonBreezyConfiguration(
      {@required String name,
      @required DataFeed feed,
      @required List<Screen> screens,
      @required List<String> sampleLog})
      : this._sampleLog = sampleLog,
        super(name: name, feed: feed, screens: screens) {
    assert(_sampleLog != null);
  }

  @override
  Future<List<String>> getSampleLog(AssetBundle bundle) async {
    return _sampleLog;
  }
}

class _DefaultBreezyConfiguration extends BreezyConfiguration {
  _DefaultBreezyConfiguration(
      {@required String name,
      @required DataFeed feed,
      @required List<Screen> screens})
      : super(name: name, feed: feed, screens: screens);

  @override
  Future<List<String>> getSampleLog(AssetBundle bundle) async {
    final int _cr = '\r'.codeUnitAt(0);
    final int _newline = '\n'.codeUnitAt(0);
    ByteData d = await bundle.load('assets/demo.log');
    final bytes = d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    final result = List<String>();
    final lineBuffer = StringBuffer();
    for (int ch in bytes) {
      if (ch == _cr) {
        // skip
      } else if (ch == _newline) {
        result.add(lineBuffer.toString());
        lineBuffer.clear();
      } else {
        lineBuffer.writeCharCode(ch);
      }
    }
    return result;
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
  final String protocolName;
  final int protocolVersion;
  final int timeModulus;
  final List<Value> chartedValues;
  final List<Value> displayedValues;
  final Map<_DequeSelector, int> dequeIndexMap;
  final bool screenSwitchCommand;
  final bool checksumIsOptional;
  final int numFeedValues;

  DataFeed(
      {@required this.protocolName,
      @required this.protocolVersion,
      @required this.timeModulus,
      @required this.chartedValues,
      @required this.displayedValues,
      @required this.dequeIndexMap,
      @required this.screenSwitchCommand,
      @required this.checksumIsOptional,
      @required this.numFeedValues});

  Map<String, Object> toJson() {
    final values = List<Value>(numFeedValues);
    for (final v in chartedValues) {
      values[v.feedIndex] = v;
    }
    for (final v in displayedValues) {
      values[v.feedIndex] = v;
      // It's OK if it appears in both lists
    }
    assert(!values.any((v) => v == null));
    return {
      'type': 'DataFeed',
      'protocolName': protocolName,
      'protocolVersion': protocolVersion,
      'timeModulus': timeModulus,
      'values': values,
      'screenSwtichCommand': screenSwitchCommand,
      'checksumIsOptional': checksumIsOptional
    };
  }

  static DataFeed _fromJson(_JsonHelper json) {
    json.expect('type', 'DataFeed');
    final valueIndex = _ValueIndex();
    Value makeValue(_JsonHelper json, int index) {
      return Value._fromJson(json, valueIndex, index);
    }

    final values = json.decodeList('values', makeValue);
    final chartedValues = List<Value>(valueIndex.charted.length);
    final displayedValues = List<Value>(valueIndex.displayed.length);
    for (final v in values) {
      int i = valueIndex.charted[v];
      if (i != null) {
        chartedValues[i] = v;
      }
      i = valueIndex.displayed[v];
      if (i != null) {
        displayedValues[valueIndex.displayed[v]] = v;
      }
    }
    assert(!chartedValues.any((v) => v == null));
    assert(!displayedValues.any((v) => v == null));
    return DataFeed(
        protocolName: json['protocolName'] as String,
        protocolVersion: json['protocolVersion'] as int,
        timeModulus: json['timeModulus'] as int,
        chartedValues: chartedValues,
        displayedValues: displayedValues,
        dequeIndexMap: json.dequeIndexMapper.dequeIndexMap,
        screenSwitchCommand: json['screenSwitchCommand'] as bool,
        checksumIsOptional: json['screenSwitchCommand'] as bool,
        numFeedValues: values.length);
    // Thats one for "breezy", one for the version #, one for time,
    // one for the checksum, and one for the screen switch command, if present.
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

class _ValueIndex {
  final charted = Map<Value, int>();
  final displayed = Map<Value, int>();
}

class Value {
  final double demoMinValue;
  final double demoMaxValue;
  final List<DataDisplayer> displayers;
  final int feedIndex;

  Value(
      {@required this.demoMinValue,
      @required this.demoMaxValue,
      @required this.displayers,
      @required this.feedIndex});

  Map<String, Object> toJson() => {
        'type': 'Value',
        'demoMinValue': demoMinValue,
        'demoMaxValue': demoMaxValue,
        'displayers': displayers.map((d) => d.toJson()).toList(growable: false)
      };

  String formatValue(double value) => '$value';

  String formatFeedValue(String value) => value;

  static Value _fromJson(
      _JsonHelper json, _ValueIndex valueIndex, int feedIndex) {
    final type = json['type'] as String;
    final demoMinValue = json['demoMinValue'] as double;
    final demoMaxValue = json['demoMaxValue'] as double;
    final displayers = List<DataDisplayer>((json['displayers'] as List).length);
    Value v;
    switch (type) {
      case 'Value':
        v = Value(
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);
        break;
      case 'FormattedValue':
        v = FormattedValue(
            format: json['demoFormat'] as String,
            keepOriginalFormat: json['keepOriginalFormat'] as bool,
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);
        break;
      case 'RatioValue':
        v = RatioValue(
            format: json['demoFormat'] as String,
            keepOriginalFormat: json['keepOriginalFormat'] as bool,
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);
        break;
      default:
        throw ArgumentError('Unknown value type:  $type');
    }
    DataDisplayer makeDisplayer(_JsonHelper json, int index) {
      return DataDisplayer._fromJson(json, v, valueIndex);
    }

    v.displayers.replaceRange(
        0, v.displayers.length, json.decodeList('displayers', makeDisplayer));
    return v;
  }
}

class FormattedValue extends Value {
  final NumberFormat format;
  final String _formatPattern;
  final bool keepOriginalFormat;

  FormattedValue(
      {@required String format,
      @required this.keepOriginalFormat,
      @required double demoMinValue,
      @required double demoMaxValue,
      @required List<DataDisplayer> displayers,
      @required int feedIndex})
      : this.format = NumberFormat(format),
        this._formatPattern = format,
        super(
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);

  @override
  String formatValue(double value) => format.format(value);

  @override
  String formatFeedValue(String value) => keepOriginalFormat
      ? value
      : formatValue(double.tryParse(value) ?? double.nan);

  String get _jsonTypeName => 'FormattedValue';

  Map<String, Object> toJson() => {
        'type': _jsonTypeName,
        'format': _formatPattern,
        'keepOriginalFormat': keepOriginalFormat,
        'demoMinValue': demoMinValue,
        'demoMaxValue': demoMaxValue,
        'displayers': displayers.map((d) => d.toJson()).toList(growable: false),
      };
}

class RatioValue extends FormattedValue {
  RatioValue(
      {@required String format,
      @required bool keepOriginalFormat,
      @required double demoMinValue,
      @required double demoMaxValue,
      @required List<DataDisplayer> displayers,
      @required int feedIndex})
      : super(
            format: format,
            keepOriginalFormat: keepOriginalFormat,
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);

  String formatValue(double value) {
    if (value >= 1.0) {
      return format.format(value) + ':1';
    } else {
      return '1:' + format.format(1 / value);
    }
  }

  @override
  String get _jsonTypeName => 'RatioValue';
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
    return {
      'type': 'Screen',
      'name': name,
      'portrait': portrait.toJson(),
      'landscape': (portrait == landscape) ? null : landscape.toJson(),
    };
  }

  static Screen _fromJson(_JsonHelper json, int index) {
    json.expect('type', 'Screen');
    var portrait = (json.getOrNull('portrait') == null)
        ? null
        : json.decode('portrait', ScreenWidget._fromJson) as ScreenContainer;
    final landscape = (json.getOrNull('landscape') == null)
        ? portrait
        : json.decode('landscape', ScreenWidget._fromJson) as ScreenContainer;
    if (landscape == null) {
      throw ArgumentError('No portrait or landscape screen layout.');
    }
    if (portrait == null) {
      portrait = landscape;
    }
    return Screen(
      name: json['name'] as String,
      portrait: portrait,
      landscape: landscape,
    )..init();
  }
}

abstract class DataDisplayer {
  final String id;

  DataDisplayer(this.id);

  Map<String, Object> toJson();
  material.Widget build(HistoricalData data);

  static DataDisplayer _fromJson(
      _JsonHelper json, Value value, _ValueIndex valueIndex) {
    int indexFor(Value v, Map<Value, int> index) {
      int i = index[v];
      if (i == null) {
        i = index.length;
        index[v] = i;
      }
      return i;
    }

    final type = json['type'];
    if (type == 'TimeChart') {
      return TimeChart._fromJson(json, indexFor(value, valueIndex.charted));
    } else if (type == 'ValueBox') {
      return ValueBox._fromJson(json, indexFor(value, valueIndex.displayed));
    } else {
      throw ArgumentError('Bad DataDisplayer type $type');
    }
  }
}

class ValueBox extends DataDisplayer {
  final int _valueIndex;
  final String label;
  final double labelHeightFactor;
  final String units;
  final String format;
  final Color color;
  final String prefix;
  final String postfix;
  ValueBox(
      {@required String id,
      @required int valueIndex,
      @required this.label,
      @required this.labelHeightFactor,
      @required this.units,
      @required this.format,
      @required this.color,
      this.prefix,
      this.postfix})
      : this._valueIndex = valueIndex,
        super(id) {
    assert(_valueIndex != null);
  }

  @override
  material.Widget build(HistoricalData data) => ui.ValueBox(
      value: data.current?.displayedValues?.elementAt(_valueIndex),
      label: label,
      labelHeightFactor: labelHeightFactor,
      format: format,
      color: color,
      units: units,
      prefix: prefix,
      postfix: postfix);

  Map<String, Object> toJson() => {
        'type': 'ValueBox',
        'id': id,
        'label': label,
        'labelHeightFactor': labelHeightFactor,
        'units': units,
        'format': format,
        'color': _encodeColor(color),
        'prefix': prefix,
        'postfix': postfix
      };

  static ValueBox _fromJson(_JsonHelper json, int index) {
    assert(json['type'] == 'ValueBox');
    final vb = ValueBox(
        id: json['id'] as String,
        valueIndex: index,
        label: json['label'] as String,
        labelHeightFactor: json['labelHeightFactor'] as double,
        units: json.getOrNull('units') as String,
        format: json['format'] as String,
        color: json.getColor('color'),
        prefix: json.getOrNull('prefix') as String,
        postfix: json.getOrNull('postfix') as String);
    json.registerDisplayer(vb);
    return vb;
  }
}

class TimeChart extends DataDisplayer
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
  final int _dequeIndex;
  final int _valueIndex;

  TimeChart(
      {@required String id,
      this.rolling = true,
      @required this.minValue,
      @required this.maxValue,
      @required this.timeSpan,
      @required this.maxNumValues,
      @required this.displayedTimeTicks,
      @required this.color,
      @required this.label,
      @required this.labelHeightFactor,
      @required int valueIndex,
      @required _DequeIndexMapper mapper})
      : _valueIndex = valueIndex,
        _dequeIndex = mapper.getDequeIndex(rolling, timeSpan, maxNumValues),
        super(id);

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
  double getValue(ChartData data) => data.values?.elementAt(_valueIndex);

  Map<String, Object> toJson() => {
        'type': 'TimeChart',
        'id': id,
        'rolling': rolling,
        'minValue': minValue,
        'maxValue': maxValue,
        'timeSpan': timeSpan,
        'maxNumValues': maxNumValues,
        'displayedTimeTicks': displayedTimeTicks,
        'color': color.rgbaHexString,
        'label': label,
        'labelHeightFactor': labelHeightFactor
      };

  static TimeChart _fromJson(_JsonHelper json, int index) {
    assert(json['type'] == 'TimeChart');
    final tc = TimeChart(
        id: json['id'] as String,
        rolling: json['rolling'] as bool,
        minValue: json['minValue'] as double,
        maxValue: json['maxValue'] as double,
        timeSpan: json['timeSpan'] as double,
        maxNumValues: json['maxNumValues'] as int,
        displayedTimeTicks: json['displayedTimeTicks'] as int,
        color: charts.Color.fromHex(code: json['color'] as String),
        label: json['label'] as String,
        labelHeightFactor: json['labelHeightFactor'] as double,
        valueIndex: index,
        mapper: json.dequeIndexMapper);
    json.registerDisplayer(tc);
    return tc;
  }
}

abstract class ScreenWidget {
  /// Defaults to 1.  Ignored for root node.
  final int flex;
  bool hasParent = true;

  ScreenWidget(this.flex);

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

  Map<String, Object> toJson();

  static ScreenWidget _fromJson(_JsonHelper json) {
    switch (json['type'] as String) {
      case 'ScreenColumn':
        return ScreenColumn(
            flex: json['flex'] as int,
            content: json.decodeList('content', ScreenWidget._fromJsonInList));
      case 'ScreenRow':
        return ScreenRow(
            flex: json['flex'] as int,
            content: json.decodeList('content', ScreenWidget._fromJsonInList));
      case 'Spacer':
        return Spacer(json['flex'] as int);
      case 'ScreenSwitchArrow':
        return ScreenSwitchArrow(
            flex: json['flex'] as int, color: json.getColor('color'));
      case 'Label':
        return Label(
            flex: json['flex'] as int,
            text: json['text'] as String,
            color: json.getColor('color'));
      case 'DataWidget':
        return DataWidget(
            flex: json['flex'] as int, displayer: json.findDisplayer('dataID'));
    }
    throw ArgumentError('Unexpected type ${json['type']}');
  }

  static ScreenWidget _fromJsonInList(_JsonHelper json, int index) =>
      _fromJson(json);
}

class Spacer extends ScreenWidget {
  Spacer(int flex) : super(flex);

  @override
  material.Widget build(HistoricalData data) {
    return material.Spacer(flex: flex);
  }

  @override
  Map<String, Object> toJson() => {'type': 'Spacer', 'flex': flex};
}

class ScreenSwitchArrow extends ScreenWidget {
  final Color color;

  ScreenSwitchArrow({int flex = 1, @required this.color}) : super(flex);

  @override
  material.Widget build(HistoricalData data) {
    return material.Expanded(
      child: material.FittedBox(
          fit: material.BoxFit.contain,
          child: material.IconButton(
              icon: material.Icon(material.Icons.navigate_next),
              tooltip: 'Next Screen',
              color: color,
              onPressed: data.advanceScreen)),
    );
  }

  @override
  Map<String, Object> toJson() =>
      {'type': 'ScreenSwitchArrow', 'flex': flex, 'color': _encodeColor(color)};
}

class Label extends ScreenWidget {
  final String text;
  final Color color;

  Label({@required int flex, @required this.text, @required this.color})
      : super(flex);

  material.Widget build(HistoricalData data) => _wrapIfNeeded(
      material.Text(text, style: material.TextStyle(color: color)));

  @override
  Map<String, Object> toJson() => {
        'type': 'Label',
        'text': text,
        'color': _encodeColor(color),
        'flex': flex
      };
}

abstract class ScreenContainer extends ScreenWidget {
  final List<ScreenWidget> content;
  ScreenContainer({@required int flex, @required this.content}) : super(flex);

  String get _jsonTypeName;

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

  @override
  Map<String, Object> toJson() => {
        'type': _jsonTypeName,
        'content': content.map((w) => w.toJson()).toList(growable: false),
        'flex': flex
      };
}

class ScreenColumn extends ScreenContainer {
  ScreenColumn({int flex = 1, @required List<ScreenWidget> content})
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

  @override
  String get _jsonTypeName => 'ScreenColumn';
}

class ScreenRow extends ScreenContainer {
  ScreenRow({int flex = 1, @required List<ScreenWidget> content})
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

  @override
  String get _jsonTypeName => 'ScreenRow';
}

class DataWidget extends ScreenWidget {
  final DataDisplayer displayer;

  DataWidget({int flex = 1, @required this.displayer}) : super(flex);

  @override
  material.Widget build(HistoricalData data) {
    return _wrapIfNeeded(displayer.build(data));
  }

  @override
  Map<String, Object> toJson() =>
      {'type': 'DataWidget', 'dataID': displayer.id, 'flex': flex};
}

DataFeed _defaultFeed() {
  final mapper = _DequeIndexMapper();
  final labelHeight = 0.24;
  return DataFeed(
      protocolName: 'breezy',
      protocolVersion: 1,
      timeModulus: 0x10000,
      numFeedValues: 14,
      screenSwitchCommand: false,
      checksumIsOptional: true,
      chartedValues: [
        Value(
          feedIndex: 0,
          demoMinValue: -10,
          demoMaxValue: 50,
          displayers: [
            TimeChart(
                id: 'c:pressure',
                valueIndex: 0,
                color: charts.MaterialPalette.deepOrange.shadeDefault.lighter,
                displayedTimeTicks: 11,
                timeSpan: 10,
                maxNumValues: 500,
                label: 'PRESSURE cmH2O',
                labelHeightFactor: labelHeight / 2,
                minValue: -10.0,
                maxValue: 50.0,
                mapper: mapper)
          ],
        ),
        Value(
          feedIndex: 1,
          demoMinValue: -100,
          demoMaxValue: 100,
          displayers: [
            TimeChart(
                id: 'c:flow',
                valueIndex: 1,
                color: charts.MaterialPalette.green.shadeDefault.lighter,
                displayedTimeTicks: 11,
                timeSpan: 10,
                maxNumValues: 500,
                label: 'FLOW l/min',
                labelHeightFactor: labelHeight / 2,
                minValue: -100.0,
                maxValue: 100.0,
                mapper: mapper)
          ],
        ),
        Value(
          feedIndex: 2,
          demoMinValue: 0,
          demoMaxValue: 800,
          displayers: [
            TimeChart(
                id: 'c:volume',
                valueIndex: 2,
                color: charts.MaterialPalette.blue.shadeDefault.lighter,
                displayedTimeTicks: 11,
                timeSpan: 10,
                maxNumValues: 500,
                label: 'VOLUME ml',
                labelHeightFactor: labelHeight / 2,
                minValue: 0.0,
                maxValue: 800.0,
                mapper: mapper)
          ],
        )
      ],
      displayedValues: [
        FormattedValue(
          feedIndex: 3,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                id: 'v:Ppeak',
                valueIndex: 0,
                label: 'Ppeak',
                labelHeightFactor: labelHeight / 2,
                units: 'cmH2O',
                format: '##.#',
                color: material.Colors.orange.shade300)
          ],
        ),
        FormattedValue(
          feedIndex: 4,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                id: 'v:Pmean',
                valueIndex: 1,
                label: 'Pmean',
                labelHeightFactor: labelHeight,
                units: 'cmH2O',
                format: '##.#',
                color: material.Colors.orange.shade300)
          ],
        ),
        FormattedValue(
          feedIndex: 5,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                valueIndex: 2,
                id: 'v:PEEP',
                label: 'PEEP',
                units: 'cmH2O',
                labelHeightFactor: labelHeight,
                format: '##.#',
                color: material.Colors.orange.shade300)
          ],
        ),
        FormattedValue(
          feedIndex: 6,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                id: 'v:RR',
                valueIndex: 3,
                label: 'RR',
                labelHeightFactor: labelHeight,
                units: 'b/min',
                format: '##.#',
                color: material.Colors.lightGreen)
          ],
        ),
        FormattedValue(
          feedIndex: 7,
          keepOriginalFormat: true,
          format: '##0',
          demoMinValue: 0,
          demoMaxValue: 100.0,
          displayers: [
            ValueBox(
                id: 'v:O2',
                valueIndex: 4,
                label: 'O2',
                labelHeightFactor: labelHeight,
                units: null,
                format: '1##',
                color: material.Colors.lightGreen,
                postfix: '%')
          ],
        ),
        FormattedValue(
          feedIndex: 8,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                id: 'v:Ti',
                valueIndex: 5,
                label: 'Ti',
                labelHeightFactor: labelHeight,
                units: 's',
                format: '##.##',
                color: material.Colors.lightGreen)
          ],
        ),
        RatioValue(
          feedIndex: 9,
          keepOriginalFormat: true,
          format: '0.0',
          demoMinValue: 0.5,
          demoMaxValue: 2,
          displayers: [
            ValueBox(
                id: 'v:IE',
                valueIndex: 6,
                label: 'I:E',
                labelHeightFactor: labelHeight,
                units: null,
                format: '1:#,#', // ',' instead of '.' so it doesn't align
                color: material.Colors.lightGreen)
          ],
        ),
        FormattedValue(
          feedIndex: 10,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                id: 'v:MVi',
                valueIndex: 7,
                label: 'MVi',
                labelHeightFactor: labelHeight,
                units: 'l/min',
                format: '##.#',
                color: material.Colors.lightBlue)
          ],
        ),
        FormattedValue(
          feedIndex: 11,
          keepOriginalFormat: true,
          format: '#0.0',
          demoMinValue: 0,
          demoMaxValue: 99.9,
          displayers: [
            ValueBox(
                id: 'v:MVe',
                valueIndex: 8,
                label: 'MVe',
                labelHeightFactor: labelHeight,
                units: 'l/min',
                format: '##.#',
                color: material.Colors.lightBlue)
          ],
        ),
        FormattedValue(
          feedIndex: 12,
          keepOriginalFormat: true,
          format: '###0',
          demoMinValue: 0,
          demoMaxValue: 9999,
          displayers: [
            ValueBox(
                id: 'v:VTi',
                valueIndex: 9,
                label: 'VTi',
                labelHeightFactor: labelHeight,
                units: null,
                format: '####',
                color: material.Colors.lightBlue)
          ],
        ),
        FormattedValue(
            feedIndex: 13,
            keepOriginalFormat: true,
            format: '###0',
            demoMinValue: 0,
            demoMaxValue: 9999,
            displayers: [
              ValueBox(
                  id: 'v:VTe',
                  valueIndex: 10,
                  label: 'VTe',
                  labelHeightFactor: labelHeight,
                  units: 'ml',
                  format: '####',
                  color: material.Colors.lightBlue)
            ])
      ],
      dequeIndexMap: mapper.dequeIndexMap);
}

Screen _defaultScreen(DataFeed feed) {
  final landscape = ScreenRow(content: [
    ScreenColumn(flex: 8, content: [
      DataWidget(displayer: feed.chartedValues[0].displayers[0]),
      DataWidget(displayer: feed.chartedValues[1].displayers[0]),
      DataWidget(displayer: feed.chartedValues[2].displayers[0]),
    ]),
    ScreenColumn(flex: 4, content: [
      ScreenRow(content: [
        DataWidget(flex: 4, displayer: feed.displayedValues[0].displayers[0]),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[1].displayers[0]),
          DataWidget(displayer: feed.displayedValues[2].displayers[0]),
        ])
      ]),
      ScreenRow(content: [
        ScreenColumn(flex: 4, content: [
          DataWidget(displayer: feed.displayedValues[3].displayers[0]),
          DataWidget(displayer: feed.displayedValues[4].displayers[0]),
        ]),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[5].displayers[0]),
          DataWidget(displayer: feed.displayedValues[6].displayers[0]),
        ])
      ]),
      ScreenRow(content: [
        ScreenColumn(flex: 4, content: [
          DataWidget(displayer: feed.displayedValues[7].displayers[0]),
          DataWidget(displayer: feed.displayedValues[8].displayers[0]),
        ]),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[9].displayers[0]),
          DataWidget(displayer: feed.displayedValues[10].displayers[0]),
        ])
      ]),
    ])
  ]);

  final portrait = ScreenRow(content: [
    ScreenColumn(content: [
      DataWidget(flex: 2, displayer: feed.chartedValues[0].displayers[0]),
      DataWidget(flex: 2, displayer: feed.chartedValues[1].displayers[0]),
      DataWidget(flex: 2, displayer: feed.chartedValues[2].displayers[0]),
      ScreenRow(flex: 2, content: [
        DataWidget(displayer: feed.displayedValues[0].displayers[0]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[1].displayers[0]),
          DataWidget(displayer: feed.displayedValues[2].displayers[0]),
        ]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[7].displayers[0]),
          DataWidget(displayer: feed.displayedValues[8].displayers[0]),
        ]),
      ]),
      ScreenRow(flex: 2, content: [
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[3].displayers[0]),
          DataWidget(displayer: feed.displayedValues[4].displayers[0]),
        ]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[5].displayers[0]),
          DataWidget(displayer: feed.displayedValues[6].displayers[0]),
        ]),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[9].displayers[0]),
          DataWidget(displayer: feed.displayedValues[10].displayers[0]),
        ])
      ]),
    ])
  ]);

  return Screen(name: 'default', portrait: portrait, landscape: landscape);
}

String _encodeColor(Color c) => toHex(c.value, 8);

class _JsonHelper {
  final Map<Object, Object> json;
  final _DequeIndexMapper dequeIndexMapper;
  final Map<String, DataDisplayer> displayers;

  _JsonHelper(this.json)
      : this.dequeIndexMapper = _DequeIndexMapper(),
        this.displayers = Map<String, DataDisplayer>();

  _JsonHelper.child(this.json, _JsonHelper parent)
      : this.dequeIndexMapper = parent.dequeIndexMapper,
        this.displayers = parent.displayers;

  Object operator [](String key) {
    if (!json.containsKey(key)) {}
    final v = getOrNull(key);
    if (v == null) {
      throw ArgumentError('$key not found');
    }
    return v;
  }

  Object getOrNull(String key) {
    final v = json[key];
    if (v is Map) {
      return _JsonHelper.child(v, this);
    } else {
      return v;
    }
  }

  void expect(String key, Object value) {
    if (this[key] != value) {
      throw ArgumentError('Expected $value but found ${this[key]} at $key');
    }
  }

  List<E> getList<E>(String key) =>
      List<E>.from(this[key] as List<Object>, growable: false);

  Color getColor(String key) =>
      Color(int.parse(json[key] as String, radix: 16));

  E decode<E>(String key, E decoder(_JsonHelper json)) =>
      decoder(this[key] as _JsonHelper);

  List<E> decodeList<E>(String key, E decoder(_JsonHelper json, int index)) {
    int i = 0;
    return getList<Map<Object, Object>>(key)
        .map((map) => decoder(_JsonHelper.child(map, this), i++))
        .toList(growable: false);
  }

  void registerDisplayer(DataDisplayer d) {
    if (displayers.containsKey(d.id)) {
      throw ArgumentError('Duplicate value id ${d.id}');
    }
    displayers[d.id] = d;
  }

  DataDisplayer findDisplayer(String key) {
    String id = this[key] as String;
    final r = displayers[id];
    if (r == null) {
      throw ArgumentError('Value $id not found');
    }
    return r;
  }
}
