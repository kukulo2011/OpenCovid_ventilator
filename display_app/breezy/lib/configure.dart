import 'dart:convert';
import 'dart:math' show min;
import 'dart:io' show IOSink, gzip;
import 'package:meta/meta.dart';
import 'package:archive/archive_io.dart' show Crc32;
import 'package:quiver/core.dart' show hash2;
import 'package:intl/intl.dart' show NumberFormat;
import 'utils.dart' show toHex;
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

// This module describes a breezy configuration.  See the docs, in particular,
// docs/configure.svg and the accompanying document.

mixin _Commentable {
  List<String> _comment;

  void comment(String c) {
    if (_comment == null) {
      _comment = List<String>();
    }
    _comment.add(c);
  }

  Map<String, Object> withComment(bool stripComments, Map<String, Object> src) {
    if (stripComments || _comment == null) {
      return src;
    } else {
      final c = Map<String, Object>();
      c['comment'] = _comment;
      c.addAll(src);
      return c;
    }
  }
}

/// A configuration for Breezy.  C is the type of a widget color
/// (normally Color from dart:ui), and TC is the color type for a
/// TimeChart (normally Color from package:charts_flutter/flutter.dart).
/// The color types are abstracted out so that configurations can
/// be created with desktop dart.  Sigh.
abstract class BreezyConfiguration<C, TC> with _Commentable {
  final DataFeed<C, TC> feed;
  final String name;
  final List<Screen<C, TC>> screens;
  Future<List<String>> getSampleLog();
  Map<String, int> _screenNumByName;

  BreezyConfiguration(
      {@required this.name, @required this.feed, @required this.screens}) {
    assert(feed != null);
    assert(screens != null);
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

  /// Output this configuration as a map, suitable to be written out
  /// with JsonEncoder.
  Future<Map<String, Object>> toJson({bool stripComments = false}) async {
    return withComment(stripComments, {
      'type': 'BreezyConfiguration',
      'version': 2,
      'name': name,
      'feed': feed.toJson(colorHelper, stripComments),
      'screens': screens
          .map((s) => s.toJson(colorHelper, stripComments))
          .toList(growable: false),
      'sampleLog': await getSampleLog()
    });
  }

  ColorHelper<C, TC> get colorHelper;

  Future<void> writeJson(IOSink sink) async {
    final json = await toJson();
    sink.writeln(JsonEncoder.withIndent('  ').convert(json));
    sink.writeln('');
  }

  /// Write out a compact representation, consisting of base64-encoded
  /// gzipped JSON, plus a Crc32 checksum.
  Future<void> writeCompact(IOSink sink) async {
    String str = JsonEncoder().convert(await toJson(stripComments: true));
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

class BadConfigurationVersion implements Exception {
  final String message;

  BadConfigurationVersion(this.message);

  String toString() {
    if (message == null) return "BadConfigurationException";
    return "BadConfigurationException: $message";
  }
}

/// A little data class to identify a deque
class _DequeSelector {
  final bool isRolling;
  final double timeSpan;

  _DequeSelector(this.isRolling, this.timeSpan);

  @override
  bool operator ==(Object o) =>
      o is _DequeSelector &&
      isRolling == o.isRolling &&
      timeSpan == o.timeSpan;

  @override
  int get hashCode => hash2(isRolling, timeSpan);
}

/// A class to build up a deque index map, to map the characteristics
/// of needed deques to their eventual indices in HistoricalData.
class DequeIndexMapper {
  final dequeIndexMap = Map<_DequeSelector, int>();

  int getDequeIndex(bool isRolling, double timeSpan) {
    final sel = _DequeSelector(isRolling, timeSpan);
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

/// A description of a data feed, including the components that are used
/// to display the values.
class DataFeed<C, TC> with _Commentable {
  final String protocolName;
  final int protocolVersion;
  final int timeModulus;
  final double ticksPerSecond;
  final List<Value<C, TC>> chartedValues;
  final List<Value<C, TC>> displayedValues;
  final Map<_DequeSelector, int> dequeIndexMap;
  final bool screenSwitchCommand;
  final bool checksumIsOptional;
  final int numFeedValues;

  DataFeed(
      {@required this.protocolName,
      @required this.protocolVersion,
      @required this.timeModulus,
      @required this.ticksPerSecond,
      @required this.chartedValues,
      @required this.displayedValues,
      @required this.dequeIndexMap,
      @required this.screenSwitchCommand,
      @required this.checksumIsOptional,
      @required this.numFeedValues}) {
    final wasSeen = Set<Value>();
    final feedIndexSeen = List<bool>.filled(numFeedValues, false);
    for (int i = 0; i < chartedValues.length; i++) {
      final v = chartedValues[i];
      wasSeen.add(v);
      assert (!feedIndexSeen[v.feedIndex]);
      feedIndexSeen[v.feedIndex] = true;
      for (final d in v.displayers) {
        if (d is TimeChart) {
          final tc = d as TimeChart;
          assert(tc._valueIndex == null);
          tc._valueIndex = i;
        }
      }
    }
    for (int i = 0; i < displayedValues.length; i++) {
      final v = displayedValues[i];
      if (!wasSeen.contains(v)) {
        wasSeen.add(v);
        assert (!feedIndexSeen[v.feedIndex]);
        feedIndexSeen[v.feedIndex] = true;
      }
      for (final d in v.displayers) {
        if (d is ValueBox) {
          final vb = d as ValueBox;
          assert(vb._valueIndex == null);
          vb._valueIndex = i;
        }
      }
    }

  }

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) {
    final values = List<Map<String, Object>>(numFeedValues);
    for (final v in chartedValues) {
      values[v.feedIndex] = v.toJson(helper, stripComments);
    }
    for (final v in displayedValues) {
      values[v.feedIndex] = v.toJson(helper, stripComments);
      // It's OK if it appears in both lists
    }
    assert(!values.any((v) => v == null));
    return withComment(stripComments, {
      'type': 'DataFeed',
      'protocolName': protocolName,
      'protocolVersion': protocolVersion,
      'timeModulus': timeModulus,
      'ticksPerSecond': ticksPerSecond,
      'values': values,
      'screenSwitchCommand': screenSwitchCommand,
      'checksumIsOptional': checksumIsOptional
    });
  }

  static DataFeed<C, TC> fromJson<C, TC>(JsonHelper<C, TC> json) {
    json.expect('type', 'DataFeed');
    final valueIndex = _ValueIndex();
    Value<C, TC> makeValue(JsonHelper<C, TC> json, int index) {
      return Value._fromJson(json, valueIndex, index);
    }

    final values = json.decodeList('values', makeValue);
    final chartedValues = List<Value<C, TC>>(valueIndex.charted.length);
    final displayedValues = List<Value<C, TC>>(valueIndex.displayed.length);
    for (final v in values) {
      final int ci = valueIndex.charted[v];
      if (ci != null) {
        chartedValues[ci] = v;
      }
      final int vi = valueIndex.displayed[v];
      if (vi != null) {
        displayedValues[vi] = v;
      }
      assert(ci != null || vi != null);
    }
    assert(!chartedValues.any((v) => v == null));
    assert(!displayedValues.any((v) => v == null));
    return DataFeed<C, TC>(
        protocolName: json['protocolName'] as String,
        protocolVersion: json['protocolVersion'] as int,
        timeModulus: json.getOrNull('timeModulus') as int,
        ticksPerSecond: (json['ticksPerSecond'] as num).toDouble(),
        chartedValues: chartedValues,
        displayedValues: displayedValues,
        dequeIndexMap: json.dequeIndexMapper.dequeIndexMap,
        screenSwitchCommand: json['screenSwitchCommand'] as bool,
        checksumIsOptional: json['checksumIsOptional'] as bool,
        numFeedValues: values.length);
    // Thats one for "breezy", one for the version #, one for time,
    // one for the checksum, and one for the screen switch command, if present.
  }

  List<WindowedData<ChartData>> createDeques() {
    final result = List<WindowedData<ChartData>>(dequeIndexMap.length);
    dequeIndexMap.forEach((sel, i) {
      if (sel.isRolling) {
        result[i] = RollingDeque<ChartData>(sel.timeSpan,
            sel.timeSpan / 20, (double time) => ChartData.dummy(time));
      } else {
        result[i] = SlidingDeque<ChartData>(sel.timeSpan);
      }
    });
    return result;
  }
}

/// A place to the index in of values.  A value can appear in both places.  If
/// a value has no displayers, it's put in "displayed," since displayed values
/// are cheaper - we don't keep a history of displayed values.
class _ValueIndex {
  final charted = Map<Value, int>();
  final displayed = Map<Value, int>();
}

/// A description of a value in a data feed.
class Value<C, TC> with _Commentable {
  final double demoMinValue;
  final double demoMaxValue;
  final List<DataDisplayer<C, TC>> displayers;
  final int feedIndex;

  Value(
      {@required this.demoMinValue,
      @required this.demoMaxValue,
      @required this.displayers,
      @required this.feedIndex});

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': 'Value',
        'demoMinValue': demoMinValue,
        'demoMaxValue': demoMaxValue,
        'displayers': displayers
            .map((d) => d.toJson(helper, stripComments))
            .toList(growable: false)
      });

  /// Format a double appropriately.  This is useful for the screen demo
  /// function to come up with credible-looking random-ish values to
  /// display.
  String formatValue(double value) => '$value';

  /// Format a string value for a feed:
  ///    \\ becomes \
  ///    \c becomes ,
  ///    \n becomes newline
  /// This lets us have commas and newlines in string values in the feed.
  /// Remember, it's sent as a comma-separated value, newline-terminated
  /// bit of text.
  String formatFeedValue(String value) {
    if (!value.contains('\\')) {
      return value;
    }

    final backslash = '\\'.codeUnitAt(0);
    final letterC = 'c'.codeUnitAt(0);
    final letterN  = 'n'.codeUnitAt(0);
    final result = StringBuffer();
    bool backslashSeen = false;
    for (final ch in value.codeUnits) {
      if (backslashSeen) {
        if (ch == letterC) {
          backslashSeen = false;
          result.write(',');
          continue;
        } else if (ch == letterN) {
          backslashSeen = false;
          result.write('\n');
          continue;
        } else if (ch == backslash) {
          backslashSeen = false;
          result.writeCharCode(backslash);
          continue;
        } else {
          result.writeCharCode(backslash);
          // And fall through...
        }
      }
      backslashSeen = ch == backslash;
      if (!backslashSeen) {
        result.writeCharCode(ch);
      }
    }
    if (backslashSeen) {
      result.writeCharCode(backslash);
    }
    return result.toString();
  }

  static Value<C, TC> _fromJson<C, TC>(
      JsonHelper<C, TC> json, _ValueIndex valueIndex, int feedIndex) {
    final type = json['type'] as String;
    final demoMinValue = (json['demoMinValue'] as num).toDouble();
    final demoMaxValue = (json['demoMaxValue'] as num).toDouble();
    final displayers =
        List<DataDisplayer<C, TC>>((json['displayers'] as List).length);
    Value<C, TC> v;
    switch (type) {
      case 'Value':
        v = Value<C, TC>(
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);
        break;
      case 'FormattedValue':
        v = FormattedValue<C, TC>(
            format: json['format'] as String,
            keepOriginalFormat: json['keepOriginalFormat'] as bool,
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);
        break;
      case 'RatioValue':
        v = RatioValue<C, TC>(
            format: json['format'] as String,
            keepOriginalFormat: json['keepOriginalFormat'] as bool,
            demoMinValue: demoMinValue,
            demoMaxValue: demoMaxValue,
            displayers: displayers,
            feedIndex: feedIndex);
        break;
      default:
        throw ArgumentError('Unknown value type:  $type');
    }
    DataDisplayer<C, TC> makeDisplayer(JsonHelper<C, TC> json, int index) {
      return DataDisplayer._fromJson<C, TC>(json, v, valueIndex);
    }

    final nd = json.decodeList('displayers', makeDisplayer);
    assert(nd.length == displayers.length);
    if (nd.isEmpty) {
      // A value with no displayers.  We put it in displayedValues, so that
      // the feed gets read and validated, and so that we don't need any
      // special cases.
      assert(valueIndex.charted[v] == null);
      assert(valueIndex.displayed[v] == null);
      valueIndex.displayed[v] = valueIndex.displayed.length;
    }
    for (int i = 0; i < nd.length; i++) {
      v.displayers[i] = nd[i];
    }
    return v;
  }
}

/// A value with an expected format.  If keepOriginalFormat is true, the
/// string from the feed is displayed on the screen; otherwise the feed
/// value is re-formatted.  The format is also useful for the screen demo
/// function, which generates random-ish values for display.
class FormattedValue<C, TC> extends Value<C, TC> {
  final NumberFormat format;
  final String _formatPattern;
  final bool keepOriginalFormat;

  FormattedValue(
      {@required String format,
      @required this.keepOriginalFormat,
      @required double demoMinValue,
      @required double demoMaxValue,
      @required List<DataDisplayer<C, TC>> displayers,
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
      ? super.formatFeedValue(value)
      : formatValue(double.tryParse(value) ?? double.nan);

  String get _jsonTypeName => 'FormattedValue';

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': _jsonTypeName,
        'format': _formatPattern,
        'keepOriginalFormat': keepOriginalFormat,
        'demoMinValue': demoMinValue,
        'demoMaxValue': demoMaxValue,
        'displayers': displayers
            .map((d) => d.toJson(helper, stripComments))
            .toList(growable: false),
      });
}

/// A special value that diplays as "1:n" or "n:1", depending on whether
/// the underlying value i < 1.0 or not.
class RatioValue<C, TC> extends FormattedValue<C, TC> {
  RatioValue(
      {@required String format,
      @required bool keepOriginalFormat,
      @required double demoMinValue,
      @required double demoMaxValue,
      @required List<DataDisplayer<C, TC>> displayers,
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

/// Definition of the appearance of a screen.  The user can switch between
/// screens using a ScreenSwitchArrow, or the feed can have a value that
/// switches screens.
class Screen<C, TC> with _Commentable {
  final String name;
  final ScreenContainer portrait;
  final ScreenContainer landscape;

  Screen(
      {@required this.name,
      @required ScreenContainer portrait,
      ScreenContainer landscape})
      : this.portrait = (portrait == null) ? landscape : portrait,
        this.landscape = (landscape == null) ? portrait : landscape {
    assert(this.name != null);
    assert(this.portrait != null);
    assert(this.landscape != null);
  }

  void init() {
    portrait.init(null);
    if (portrait != landscape) {
      landscape.init(null);
    }
  }

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': 'Screen',
        'name': name,
        'portrait': portrait.toJson(helper, stripComments),
        'landscape': (portrait == landscape)
            ? null
            : landscape.toJson(helper, stripComments),
      });

  static Screen<C, TC> fromJson<C, TC>(JsonHelper<C, TC> json, int index) {
    json.expect('type', 'Screen');
    var portrait = (json.getOrNull('portrait') == null)
        ? null
        : json.decode('portrait', ScreenWidget._fromJson) as ScreenContainer;
    final landscape = (json.getOrNull('landscape') == null)
        ? null
        : json.decode('landscape', ScreenWidget._fromJson) as ScreenContainer;
    if (landscape == null && portrait == null) {
      throw ArgumentError('No portrait or landscape screen layout.');
    }
    return Screen<C, TC>(
      name: json['name'] as String,
      portrait: portrait,
      landscape: landscape,
    )..init();
  }
}

/// A component of a feed's value that displays data.
abstract class DataDisplayer<C, TC> with _Commentable {
  final String id;

  DataDisplayer(this.id);

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments);

  void accept(ScreenWidgetVisitor<C, TC> v);

  static DataDisplayer<C, TC> _fromJson<C, TC>(
      JsonHelper<C, TC> json, Value<C, TC> value, _ValueIndex valueIndex) {
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
      return TimeChart._fromJson<C, TC>(
          json, indexFor(value, valueIndex.charted));
    } else if (type == 'ValueBox') {
      return ValueBox._fromJson<C, TC>(
          json, indexFor(value, valueIndex.displayed));
    } else {
      throw ArgumentError('Bad DataDisplayer type $type');
    }
  }
}

/// A box that contains a numeric or string value.
class ValueBox<C, TC> extends DataDisplayer<C, TC> {
  int _valueIndex;
  int get valueIndex {
    assert(_valueIndex != null);
    return _valueIndex;
  }

  final String label;
  final double labelHeightFactor;
  final String units;
  final String format;
  final ValueAlignment alignment;
  final C color;
  final String prefix;
  final String postfix;
  ValueBox(
      {@required String id,
      @required this.label,
      @required this.labelHeightFactor,
      @required this.units,
      @required this.format,
      @required this.color,
      this.alignment = ValueAlignment.decimal,
      this.prefix,
      this.postfix})
      : super(id);

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': 'ValueBox',
        'id': id,
        'label': label,
        'labelHeightFactor': labelHeightFactor,
        'units': units,
        'format': format,
        'alignment': JsonHelper.enumName(alignment),
        'color': helper.encodeColor(color),
        'prefix': prefix,
        'postfix': postfix
      });

  static ValueBox<C, TC> _fromJson<C, TC>(JsonHelper<C, TC> json, int index) {
    assert(json['type'] == 'ValueBox');
    final ValueBox<C, TC> vb = ValueBox<C, TC>(
        id: json['id'] as String,
        label: json['label'] as String,
        labelHeightFactor: (json['labelHeightFactor'] as num).toDouble(),
        units: json.getOrNull('units') as String,
        format: json['format'] as String,
        alignment: json.getAlignment('alignment'),
        color: json.getColor('color'),
        prefix: json.getOrNull('prefix') as String,
        postfix: json.getOrNull('postfix') as String);
    json.registerDisplayer(vb);
    return vb;
  }

  @override
  void accept(ScreenWidgetVisitor v) => v.visitValueBox(this);
}

/// A chart to display a value with time as the X axis.
class TimeChart<C, TC> extends DataDisplayer<C, TC> {
  final bool rolling;
  final double minValue;
  final double maxValue;
  final double timeSpan;
  final int displayedTimeTicks;
  final TC color;
  final String label;
  final double labelHeightFactor;
  final int dequeIndex;
  int _valueIndex;
  int get valueIndex {
    assert(_valueIndex != null);
    return _valueIndex;
  }

  TimeChart(
      {@required String id,
      this.rolling = true,
      @required this.minValue,
      @required this.maxValue,
      @required this.timeSpan,
      @required this.displayedTimeTicks,
      @required this.color,
      @required this.label,
      @required this.labelHeightFactor,
      @required DequeIndexMapper mapper})
      : dequeIndex = mapper.getDequeIndex(rolling, timeSpan),
        super(id) {
    assert(this.color != null);
  }

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': 'TimeChart',
        'id': id,
        'rolling': rolling,
        'minValue': minValue,
        'maxValue': maxValue,
        'timeSpan': timeSpan,
        'displayedTimeTicks': displayedTimeTicks,
        'color': helper.encodeChartColor(color),
        'label': label,
        'labelHeightFactor': labelHeightFactor
      });

  static TimeChart<C, TC> _fromJson<C, TC>(JsonHelper<C, TC> json, int index) {
    assert(json['type'] == 'TimeChart');
    final tc = TimeChart<C, TC>(
        id: json['id'] as String,
        rolling: json['rolling'] as bool,
        minValue: (json['minValue'] as num).toDouble(),
        maxValue: (json['maxValue'] as num).toDouble(),
        timeSpan: (json['timeSpan'] as num).toDouble(),
        displayedTimeTicks: json['displayedTimeTicks'] as int,
        color: json.getChartColor('color'),
        label: json['label'] as String,
        labelHeightFactor: (json['labelHeightFactor'] as num).toDouble(),
        mapper: json.dequeIndexMapper);
    json.registerDisplayer(tc);
    return tc;
  }

  @override
  void accept(ScreenWidgetVisitor v) => v.visitTimeChart(this);
}

/// A visitor for a tree of ScreenWidget instances.  The visitor pattern allows
/// us to avoid any coupling between this module and Android-specific classes.
/// cf. `make_config/configure_dt.dart` and `make_config/weather_demo.dart`.
abstract class ScreenWidgetVisitor<C, TC> {
  void visitColumn(ScreenColumn<C, TC> w);
  void visitRow(ScreenRow<C, TC> w);
  void visitSpacer(Spacer<C, TC> w);
  void visitBorder(Border<C, TC> w);
  void visitLabel(Label<C, TC> w);
  void visitSwitchArrow(ScreenSwitchArrow<C, TC> w);
  void visitDataWidget(DataWidget<C, TC> w);
  void visitTimeChart(TimeChart<C, TC> w);
  void visitValueBox(ValueBox<C, TC> w);
}

/// A component on the screen.  Ultimately these are used to build the Flutter
/// widgets that make up the display.
abstract class ScreenWidget<C, TC> with _Commentable {
  /// Defaults to 1.  Ignored for root node.
  final int flex;
  bool hasParent = true;
  bool parentIsRow;

  ScreenWidget(this.flex);

  /// [parent] is the row or column that contains us, or null if we're
  @mustCallSuper
  void init(ScreenContainer<C, TC> parent) {
    hasParent = parent != null;
    parentIsRow = parent is ScreenRow<C, TC>;
    assert(parentIsRow || !hasParent || parent is ScreenColumn<C, TC>);
  }

  void accept(ScreenWidgetVisitor<C, TC> v);

  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments);

  static ScreenWidget<C, TC> _fromJson<C, TC>(JsonHelper<C, TC> json) {
    switch (json['type'] as String) {
      case 'ScreenColumn':
        return ScreenColumn<C, TC>(
            flex: json['flex'] as int,
            content: json.decodeList('content', ScreenWidget._fromJsonInList));
      case 'ScreenRow':
        return ScreenRow<C, TC>(
            flex: json['flex'] as int,
            content: json.decodeList('content', ScreenWidget._fromJsonInList));
      case 'Spacer':
        return Spacer<C, TC>(json['flex'] as int);
      case 'Border':
        return Border<C, TC>(
            width: (json['width'] as num).toDouble(),
            color: json.getColor('color'),
            flex: json.getOrNull('flex') as int);
      case 'ScreenSwitchArrow':
        return ScreenSwitchArrow<C, TC>(
            flex: json['flex'] as int, color: json.getColor('color'));
      case 'Label':
        return Label<C, TC>(
            flex: json['flex'] as int,
            text: json['text'] as String,
            color: json.getColor('color'));
      case 'DataWidget':
        return DataWidget<C, TC>(
            flex: json['flex'] as int, displayer: json.findDisplayer('dataID'));
    }
    throw ArgumentError('Unexpected type ${json['type']}');
  }

  static ScreenWidget<C, TC> _fromJsonInList<C, TC>(
          JsonHelper<C, TC> json, int index) =>
      _fromJson(json);
}

/// A widget to add some blank space in a layout.
class Spacer<C, TC> extends ScreenWidget<C, TC> {
  Spacer(int flex) : super(flex);

  @override
  void accept(ScreenWidgetVisitor<C, TC> v) => v.visitSpacer(this);

  @override
  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {'type': 'Spacer', 'flex': flex});
}


/// A widget to add a border.  Normally, you want a fixed width for this,
/// so the flex should usually be null.  If it's not, the width of the line
/// will scale with the screen.
class Border<C, TC> extends ScreenWidget<C, TC> {
  C color;
  double width;

  /// A border.  flex is usually left null; if set, it means the
  /// width of the border will expand to fill available space according
  /// to flex.
  Border({@required this.color, this.width=1, int flex}) : super(flex);

  @override
  void accept(ScreenWidgetVisitor<C, TC> v) => v.visitBorder(this);

  @override
  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {'type': 'Border', 'width': width,
        'color': helper.encodeColor(color),
      'flex': flex});
}

/// An arrow that lets the user switch between the various screens.
class ScreenSwitchArrow<C, TC> extends ScreenWidget<C, TC> {
  final C color;

  ScreenSwitchArrow({int flex = 1, @required this.color}) : super(flex);

  @override
  void accept(ScreenWidgetVisitor<C, TC> v) => v.visitSwitchArrow(this);

  @override
  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': 'ScreenSwitchArrow',
        'flex': flex,
        'color': helper.encodeColor(color)
      });
}

/// A fixed label.
class Label<C, TC> extends ScreenWidget<C, TC> {
  final String text;
  final C color;

  Label({int flex = 1, @required this.text, @required this.color})
      : super(flex);

  @override
  void accept(ScreenWidgetVisitor<C, TC> v) => v.visitLabel(this);

  @override
  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': 'Label',
        'text': text,
        'color': helper.encodeColor(color),
        'flex': flex
      });
}

/// A container of other widgets.
abstract class ScreenContainer<C, TC> extends ScreenWidget<C, TC> {
  final List<ScreenWidget<C, TC>> content;
  ScreenContainer({int flex=1, @required this.content}) : super(flex);

  String get _jsonTypeName;

  @override
  void init(ScreenContainer<C, TC> parent) {
    super.init(parent);
    for (final c in content) {
      c.init(this);
    }
  }

  @override
  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments, {
        'type': _jsonTypeName,
        'content': content
            .map((w) => w.toJson(helper, stripComments))
            .toList(growable: false),
        'flex': flex
      });
}

/// A set of widgets arranged in a column.
class ScreenColumn<C, TC> extends ScreenContainer<C, TC> {
  ScreenColumn({int flex = 1, @required List<ScreenWidget<C, TC>> content})
      : super(flex: flex, content: content) {
    for (final w in content) {
      assert (!(w is ScreenColumn));
    }
  }

  @override
  void accept(ScreenWidgetVisitor v) => v.visitColumn(this);

  @override
  void init(ScreenContainer<C, TC> parent) {
    super.init(parent);
    if (parent is ScreenColumn) {
      throw Exception("A column can't contain another column");
    }
  }

  @override
  String get _jsonTypeName => 'ScreenColumn';
}

/// A set of widgets arranged in a row.
class ScreenRow<C, TC> extends ScreenContainer<C, TC> {
  ScreenRow({int flex = 1, @required List<ScreenWidget<C, TC>> content})
      : super(flex: flex, content: content) {
    for (final w in content) {
      assert (!(w is ScreenRow));
    }
  }

  @override
  void init(ScreenContainer<C, TC> parent) {
    super.init(parent);
    if (parent is ScreenRow) {
      throw Exception("A row can't contain another row");
    }
  }

  @override
  void accept(ScreenWidgetVisitor<C, TC> v) => v.visitRow(this);

  @override
  String get _jsonTypeName => 'ScreenRow';
}

/// A widget that presents a DataDisplayer from a feed.
class DataWidget<C, TC> extends ScreenWidget<C, TC> {
  final DataDisplayer<C, TC> displayer;

  DataWidget({int flex = 1, @required this.displayer}) : super(flex);

  @override
  void accept(ScreenWidgetVisitor v) => v.visitDataWidget(this);

  @override
  Map<String, Object> toJson(ColorHelper<C, TC> helper, bool stripComments) =>
      withComment(stripComments,
          {'type': 'DataWidget', 'dataID': displayer.id, 'flex': flex});
}

/// A little helper class to map between hex strings and colors.  The app
/// has to deal with two different Color classes:  The normal Flutter color,
/// and (for whatever reason) the different Color class that's used by the
/// charts package.  Desktop flutter, on the other hand, doesn't have a
/// default Color class, so we use one swiped from a CSS package.  It's a mess,
/// but this class an the <C, TC> generics sprinkled throughout this module
/// resolve, with, while managing dependencies.
abstract class ColorHelper<C, TC> {
  String encodeColor(C c);
  C decodeColor(String hex);
  String encodeChartColor(TC c);
  TC decodeChartColor(String hex);
}

///  A little helper class for encoding and decoding the JSON format of a
///  configuration.
class JsonHelper<C, TC> {
  final Map<Object, Object> json;
  final DequeIndexMapper dequeIndexMapper;
  final Map<String, DataDisplayer<C, TC>> displayers;
  final ColorHelper<C, TC> colorHelper;
  static final Map<String, ValueAlignment> alignments = _populate<ValueAlignment>(ValueAlignment.values);

  JsonHelper(this.json, this.colorHelper)
      : this.dequeIndexMapper = DequeIndexMapper(),
        this.displayers = Map<String, DataDisplayer<C, TC>>();

  JsonHelper.child(this.json, JsonHelper<C, TC> parent)
      : this.dequeIndexMapper = parent.dequeIndexMapper,
        this.displayers = parent.displayers,
        this.colorHelper = parent.colorHelper;

  static Map<String, T> _populate<T>(List<T> values) {
    final result = Map<String, T>();
    for (final v in values) {
      result[enumName(v)] = v;
    }
    return result;
  }

  static String enumName<T>(T value) {
    final s = value.toString();
    return s.substring(s.indexOf('.')+1);
  }

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
      return JsonHelper<C, TC>.child(v, this);
    } else {
      return v;
    }
  }

  ValueAlignment getAlignment(String key) {
    final r = alignments[this[key] as String];
    if (r == null) {
      throw ArgumentError('Error in alignment value ${this[key]}');
    }
    return r;
  }

  void expect(String key, Object value) {
    if (this[key] != value) {
      throw ArgumentError('Expected $value but found ${this[key]} at $key');
    }
  }

  List<E> getList<E>(String key) =>
      List<E>.from(this[key] as List<Object>, growable: false);

  C getColor(String key) => colorHelper.decodeColor(json[key] as String);

  TC getChartColor(String key) =>
      colorHelper.decodeChartColor(json[key] as String);

  E decode<E>(String key, E decoder(JsonHelper<C, TC> json)) =>
      decoder(this[key] as JsonHelper<C, TC>);

  List<E> decodeList<E>(
      String key, E decoder(JsonHelper<C, TC> json, int index)) {
    int i = 0;
    return getList<Map<Object, Object>>(key)
        .map((map) => decoder(JsonHelper<C, TC>.child(map, this), i++))
        .toList(growable: false);
  }

  void registerDisplayer(DataDisplayer<C, TC> d) {
    if (displayers.containsKey(d.id)) {
      throw ArgumentError('Duplicate value id ${d.id}');
    }
    displayers[d.id] = d;
  }

  DataDisplayer<C, TC> findDisplayer(String key) {
    String id = this[key] as String;
    final r = displayers[id];
    if (r == null) {
      throw ArgumentError('Value $id not found');
    }
    return r;
  }
}
