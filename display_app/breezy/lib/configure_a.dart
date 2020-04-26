import 'dart:convert';
import 'dart:io' show File, Directory, FileSystemEntity, gzip;
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:archive/archive_io.dart' show Crc32;
import 'dart:ui' show Color;
import 'package:charts_flutter/flutter.dart' as charts;
import 'configure.dart';
import 'utils.dart';

// This module contains the Android-specific realizations of the generic
// classes in configure.dart.

/// A reader to read a configuration's JSON file.  The JSON file is expected
/// to be in a number of lines.  The end of a configuration is signaled by
/// a blank line, or an EOF.
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

  void acceptEOF() {
    assert(!_done);
    _done = true;
  }

  JsonBreezyConfiguration getResult() {
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
    return JsonBreezyConfiguration.fromJson(json);
  }
}

/// The android realiztion of BreezyConfiguration, with appropriate
/// color types.
abstract class AndroidBreezyConfiguration
    extends BreezyConfiguration<Color, charts.Color> {
  static Directory localStorage;
  static AssetBundle assetBundle;

  AndroidBreezyConfiguration(
      {@required String name,
      @required DataFeed<Color, charts.Color> feed,
      @required List<Screen<Color, charts.Color>> screens})
      : super(name: name, feed: feed, screens: screens);

  @override
  final ColorHelper<Color, charts.Color> colorHelper = AndroidColorHelper();

  Future<void> save() async {
    final dir = await localStorage.create(recursive: true);
    final f = File('${dir.path}/$name');
    if (!await FileSystemEntity.identical(dir.path, f.parent.path)) {
      throw Exception('Illegal file name in $name');
    }
    String str = JsonEncoder().convert(await toJson(stripComments: true));
    List<int> bytes = utf8.encode(str);
    str = null;
    bytes = gzip.encoder.convert(bytes);
    await f.writeAsBytes(bytes);
  }
}

/// A configuration read from JSON.
class JsonBreezyConfiguration extends AndroidBreezyConfiguration {
  final List<String> _sampleLog;

  JsonBreezyConfiguration._constructor(
      {@required String name,
      @required DataFeed<Color, charts.Color> feed,
      @required List<Screen<Color, charts.Color>> screens,
      @required List<String> sampleLog})
      : this._sampleLog = sampleLog,
        super(name: name, feed: feed, screens: screens) {
    assert(_sampleLog != null);
  }

  /// Throws various kinds of exceptions on malformed input
  static JsonBreezyConfiguration fromJson(Map<Object, Object> jsonSrc) {
    final json = JsonHelper<Color, charts.Color>(jsonSrc, AndroidColorHelper());
    json.expect('type', 'BreezyConfiguration');
    final version = json['version'] as int;
    if (version != 2) {
      throw BadConfigurationVersion('Version $version is not supported');
    }
    final DataFeed<Color, charts.Color> Function(
        JsonHelper<Color, charts.Color>) decoder = DataFeed.fromJson;
    return JsonBreezyConfiguration._constructor(
        name: json['name'] as String,
        feed: json.decode('feed', decoder),
        screens: json.decodeList('screens', Screen.fromJson),
        sampleLog: json.getList<String>('sampleLog'));
  }

  @override
  Future<List<String>> getSampleLog() async {
    return _sampleLog;
  }

  /// throws BadConfigurationException
  static Future<BreezyConfiguration> read(String name) async {
    final f = File('${AndroidBreezyConfiguration.localStorage.path}/$name');
    if (!await f.exists()) {
      throw Exception('$f not found');
    }
    List<int> bytes = await f.readAsBytes();
    bytes = gzip.decode(bytes);
    String src = utf8.decode(bytes);
    bytes = null;
    final json = jsonDecode(src) as Map<Object, Object>;
    src = null;
    return JsonBreezyConfiguration.fromJson(json);
  }

  static List<String> getStoredConfigurations() {
    try {
      AndroidBreezyConfiguration.localStorage.createSync(recursive: true);
      return AndroidBreezyConfiguration.localStorage
        .listSync()
        .map((FileSystemEntity f) => path.basename(f.path))
        .toList(growable: false)
        ..sort((s1, s2) => s1.toLowerCase().compareTo(s2.toLowerCase()));
    } catch (ex, st) {
      print(st);
      print(ex);
      return <String>[];
    }
  }

  static void delete(String name) {
    try {
      File('${AndroidBreezyConfiguration.localStorage.path}/$name')
        .deleteSync();
    } catch (ex, st) {
      print(st);
      print(ex);
    }
  }
}

/// The default configuration, created in code and using the demo log file
/// packaged as an asset.
class DefaultBreezyConfiguration extends AndroidBreezyConfiguration {
  DefaultBreezyConfiguration(
      {@required String name,
      @required DataFeed<Color, charts.Color> feed,
      @required List<Screen<Color, charts.Color>> screens})
      : super(name: name, feed: feed, screens: screens);

  static BreezyConfiguration defaultConfig = _createDefault();

  static BreezyConfiguration _createDefault() {
    final feed = _defaultFeed();
    final screens = defaultScreens(feed);
    return DefaultBreezyConfiguration(name: null, screens: screens, feed: feed);
  }

  static List<Screen<Color, charts.Color>> defaultScreens(
      DataFeed<Color, charts.Color> feed) {
    final result = [_defaultScreen(feed)];
    for (final s in result) {
      s.init();
    }
    return result;
  }

  @override
  Future<List<String>> getSampleLog() async {
    final int _cr = '\r'.codeUnitAt(0);
    final int _newline = '\n'.codeUnitAt(0);
    ByteData d =
        await AndroidBreezyConfiguration.assetBundle.load('assets/demo.log');
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

/// The Android reqalization of ColorHelper.
class AndroidColorHelper extends ColorHelper<Color, charts.Color> {
  @override
  String encodeColor(material.Color c) => toHex(c.value, 8);

  @override
  material.Color decodeColor(String hex) => Color(int.parse(hex, radix: 16));

  @override
  String encodeChartColor(charts.Color c) {
    final Color normal = Color.fromARGB(c.a, c.r, c.g, c.b);
    return encodeColor(normal);
  }

  @override
  charts.Color decodeChartColor(String hex) {
    final Color normal = decodeColor(hex);
    final r = charts.Color(
        r: normal.red, g: normal.green, b: normal.blue, a: normal.alpha);
    return r;
  }
}

/// Our default feed.  This is the definition of the feed and the screen
/// for the ventilator project.
DataFeed<Color, charts.Color> _defaultFeed() {
  final mapper = DequeIndexMapper();
  final labelHeight = 0.24;
  return DataFeed<Color, charts.Color>(
      protocolName: 'breezy',
      protocolVersion: 1,
      timeModulus: 0x10000,
      ticksPerSecond: 1000.0,
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
                color: charts.MaterialPalette.deepOrange.shadeDefault.lighter,
                displayedTimeTicks: 11,
                timeSpan: 10,
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
                color: charts.MaterialPalette.green.shadeDefault.lighter,
                displayedTimeTicks: 11,
                timeSpan: 10,
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
                color: charts.MaterialPalette.blue.shadeDefault.lighter,
                displayedTimeTicks: 11,
                timeSpan: 10,
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
                  label: 'VTe',
                  labelHeightFactor: labelHeight,
                  units: 'ml',
                  format: '####',
                  color: material.Colors.lightBlue)
            ])
      ],
      dequeIndexMap: mapper.dequeIndexMap);
}

Screen<Color, charts.Color> _defaultScreen(DataFeed<Color, charts.Color> feed) {
  final _borderColor = material.Colors.grey[700];

  final landscape = ScreenRow<Color, charts.Color>(content: [
    Border(color: _borderColor),
    ScreenColumn(flex: 8, content: [
      Border(color: _borderColor),
      DataWidget(displayer: feed.chartedValues[0].displayers[0]),
      Border(color: _borderColor),
      DataWidget(displayer: feed.chartedValues[1].displayers[0]),
      Border(color: _borderColor),
      DataWidget(displayer: feed.chartedValues[2].displayers[0]),
      Border(color: _borderColor),
    ]),
    Border(color: _borderColor),
    ScreenColumn(flex: 4, content: [
      Border(color: _borderColor),
      ScreenRow(content: [
        DataWidget(flex: 4, displayer: feed.displayedValues[0].displayers[0]),
        Border(color: _borderColor),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[1].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[2].displayers[0]),
        ]),
      ]),
      Border(color: _borderColor),
      ScreenRow(content: [
        ScreenColumn(flex: 4, content: [
          DataWidget(displayer: feed.displayedValues[3].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[4].displayers[0]),
        ]),
        Border(color: _borderColor),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[5].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[6].displayers[0]),
        ]),
      ]),
      Border(color: _borderColor),
      ScreenRow(content: [
        ScreenColumn(flex: 4, content: [
          DataWidget(displayer: feed.displayedValues[7].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[8].displayers[0]),
        ]),
        Border(color: _borderColor),
        ScreenColumn(flex: 3, content: [
          DataWidget(displayer: feed.displayedValues[9].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[10].displayers[0]),
        ]),
      ]),
      Border(color: _borderColor),
    ]),
    Border(color: _borderColor),
  ]);

  final portrait = ScreenRow<Color, charts.Color>(content: [
    Border(color: _borderColor),
    ScreenColumn(content: [
      Border(color: _borderColor),
      DataWidget(flex: 2, displayer: feed.chartedValues[0].displayers[0]),
      Border(color: _borderColor),
      DataWidget(flex: 2, displayer: feed.chartedValues[1].displayers[0]),
      Border(color: _borderColor),
      DataWidget(flex: 2, displayer: feed.chartedValues[2].displayers[0]),
      Border(color: _borderColor),
      ScreenRow(flex: 2, content: [
        DataWidget(displayer: feed.displayedValues[0].displayers[0]),
        Border(color: _borderColor),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[1].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[2].displayers[0]),
        ]),
        Border(color: _borderColor),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[7].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[8].displayers[0]),
        ]),
      ]),
      Border(color: _borderColor),
      ScreenRow(flex: 2, content: [
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[3].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[4].displayers[0]),
        ]),
        Border(color: _borderColor),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[5].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[6].displayers[0]),
        ]),
        Border(color: _borderColor),
        ScreenColumn(content: [
          DataWidget(displayer: feed.displayedValues[9].displayers[0]),
          Border(color: _borderColor),
          DataWidget(displayer: feed.displayedValues[10].displayers[0]),
        ])
      ]),
      Border(color: _borderColor),
    ]),
    Border(color: _borderColor),
  ]);

  return Screen(name: 'default', portrait: portrait, landscape: landscape);
}
