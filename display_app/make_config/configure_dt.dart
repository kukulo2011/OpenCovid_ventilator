
import 'dart:io';

// ignore: avoid_relative_lib_imports
import '../breezy/lib/configure.dart';
// ignore: avoid_relative_lib_imports
import 'package:csslib/parser.dart' show Color;
import 'package:meta/meta.dart';

/// A desktop version of BreezyConfiguration.
class DesktopBreezyConfiguration extends BreezyConfiguration<Color, Color> {

  final List<String> _sampleLog;

  DesktopBreezyConfiguration(
      {@required String name,
        @required DataFeed<Color, Color> feed,
        @required List<Screen<Color, Color>> screens,
        @required List<String> sampleLog})
      : _sampleLog = sampleLog,
        super(name: name, feed: feed, screens: screens) {
    assert(_sampleLog != null);
  }

  @override
  final ColorHelper<Color, Color> colorHelper = DesktopColorHelper();

  @override
  Future<List<String>> getSampleLog() async {
    return _sampleLog;
  }

  void printJson() {
    writeJson(stdout);
  }
}

class DesktopColorHelper extends ColorHelper<Color, Color> {
  @override
  Color decodeChartColor(String hex) => Color.hex(hex);

  @override
  Color decodeColor(String hex) => Color.hex(hex);

  @override
  String encodeChartColor(Color c) => encodeColor(c);

  @override
  String encodeColor(Color c) {
    final rgb = c.toHexArgbString();
    if (rgb.length == 6) {
      return 'ff$rgb';
    } else {
      assert(rgb.length == 8);
      return rgb;
    }
  }
}
