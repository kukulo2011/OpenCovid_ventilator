
import 'configure_dt.dart';
// ignore: avoid_relative_lib_imports
import '../breezy/lib/configure.dart';
// ignore: avoid_relative_lib_imports
import '../breezy/lib/data_types.dart';
import 'package:csslib/parser.dart' show Color;

/// Create the file weather_demo.comfig

final _mapper = DequeIndexMapper();

final _cityName = Value<Color, Color>(
    feedIndex: 0,
    demoMinValue: 0,
    demoMaxValue: 0,
    displayers: [
      ValueBox(
        id: 'cityName',
        label: 'City',
        labelHeightFactor: 0.2,
        format: 'MMMMMMMMMMMMMMM',
        alignment: ValueAlignment.center,
        color: Color.blanchedAlmond,
        units: null,
      )
    ])
  ..comment('The first data element in the feed (feedIndex 0).  This is')
  ..comment('a box that displays the city name.  The format string determines')
  ..comment("the amount of space that's reserved - make it longer and the font")
  ..comment('size will go down.');

final _date = Value<Color, Color>(
    feedIndex: 1, demoMinValue: 0, demoMaxValue: 0, displayers: [])
  ..comment("Our data feed has a date field, but we don't display it.");

final _rainfall = FormattedValue<Color, Color>(
    feedIndex: 2,
    demoMinValue: 0,
    demoMaxValue: 20,
    format: '#0.0',
    keepOriginalFormat: false,
    displayers: [
      TimeChart(
          id: 'rainfall_rolling',
          mapper: _mapper,
          rolling: true,
          minValue: 0,
          maxValue: 10,
          timeSpan: 36.5,
          displayedTimeTicks: 13,
          color: Color.aqua,
          label: 'Rainfall inches',
          labelHeightFactor: 0.12)
        ..comment('This is a chart for displaying rainfall.  It\'s "rolling",')
        ..comment('which means the values remain stationary, and the point')
        ..comment('new values is added sweeps from right to left.  timeSpan')
        ..comment(
            'is in seconds.  Each day is one "tick," converted to seconds')
        ..comment('by ticksPerSecond.'),
      TimeChart(
          id: 'rainfall_sliding',
          mapper: _mapper,
          rolling: false,
          minValue: 0,
          maxValue: 10,
          timeSpan: 36.5,
          displayedTimeTicks: 13,
          color: Color.aqua,
          label: 'Rainfall inches',
          labelHeightFactor: 0.12)
        ..comment('This is like rainfall_rolling, but it\'s a "sliding" chart.')
        ..comment(
            'That means that old vales slide off the left side of the chart.'),
      ValueBox(
          id: 'rainfall_value',
          label: 'Rainfall',
          labelHeightFactor: 0.12,
          units: 'inches',
          format: '###.0',
          color: Color.aqua)
        ..comment(
            'The same value is also displayed numerically, aligned on the')
        ..comment('decimal point.  Format is big enough for NaN to display.')
        ..comment('This format string is just used to calculate the width, and')
        ..comment('figure out where the decimal point is.')
    ])
  ..comment('Rainfall, shown both as a value and as a chart.')
  ..comment('Because keepOriginalFormat is false, the number from the')
  ..comment('feed is converted to a double then re-formatted according')
  ..comment('to the format string.');

final _lowTemp = FormattedValue<Color, Color>(
    feedIndex: 4,
    demoMinValue: -99,
    demoMaxValue: 140,
    format: '###',
    keepOriginalFormat: false,
    displayers: [
      TimeChart(
          id: 'low_rolling',
          mapper: _mapper,
          rolling: true,
          minValue: 30,
          maxValue: 100,
          timeSpan: 36.5,
          displayedTimeTicks: 13,
          color: Color.blue.lighter(0.4),
          label: 'Low °F ',
          labelHeightFactor: 0.12),
      TimeChart(
          id: 'low_sliding',
          mapper: _mapper,
          rolling: false,
          minValue: 30,
          maxValue: 100,
          timeSpan: 36.5,
          displayedTimeTicks: 13,
          color: Color.blue.lighter(0.4),
          label: 'Low °F ',
          labelHeightFactor: 0.12),
      ValueBox(
          id: 'low_value',
          label: 'Low',
          labelHeightFactor: 0.12,
          postfix: '° F',
          units: null,
          format: '1##',
          color: Color.blue.lighter(0.4))
    ])
  ..comment('Daily low temperature, shown both as a value and as a chart.')
  ..comment('Structurally this is very similar to rainfall; see')
  ..comment('the comments there');

final _highTemp = FormattedValue<Color, Color>(
    feedIndex: 3,
    demoMinValue: -99,
    demoMaxValue: 140,
    format: '###',
    keepOriginalFormat: false,
    displayers: [
      TimeChart(
          id: 'high_rolling',
          mapper: _mapper,
          rolling: true,
          minValue: 30,
          maxValue: 100,
          timeSpan: 36.5,
          displayedTimeTicks: 13,
          color: Color.red,
          label: 'High °F ',
          labelHeightFactor: 0.12),
      TimeChart(
          id: 'high_sliding',
          mapper: _mapper,
          rolling: false,
          minValue: 30,
          maxValue: 100,
          timeSpan: 36.5,
          displayedTimeTicks: 13,
          color: Color.red,
          label: 'High °F ',
          labelHeightFactor: 0.12),
      ValueBox(
          id: 'high_value',
          label: 'High',
          units: null,
          labelHeightFactor: 0.12,
          postfix: '° F',
          format: '1##',
          color: Color.red),
      TimeChart(
          id: 'high_long',
          mapper: _mapper,
          rolling: true,
          minValue: 30,
          maxValue: 100,
          timeSpan: 730,
          displayedTimeTicks: 20,
          color: Color.red,
          label: 'High °F ',
          labelHeightFactor: 0.12)
        ..comment('This chart has a time span of about 20 years\' worth of')
        ..comment('data.  With data points this dense, a sliding chart is')
        ..comment('pretty slow, so we have a rolling chart here.'),
    ])
  ..comment('Daily high temperature, shown both as a value and as a chart.')
  ..comment('This is structurally similar to rainfall; see')
  ..comment('the comments there');

final _borderColor = Color.grey.darker(0.25);

final weather_demo = DesktopBreezyConfiguration(
    name: 'weather_demo',
    feed: DataFeed(
        protocolName: 'weather_demo',
        protocolVersion: 1,
        timeModulus: null,
        ticksPerSecond: 10,
        numFeedValues: 5,
        screenSwitchCommand: false,
        checksumIsOptional: true,
        chartedValues: [_rainfall, _lowTemp, _highTemp],
        displayedValues: [_cityName, _date, _rainfall, _lowTemp, _highTemp],
        dequeIndexMap: _mapper.dequeIndexMap)
      ..comment('Our data feed, consisting of five real values, plus a format')
      ..comment('name, format version, time value, and checksum.')
      ..comment('')
      ..comment('Since checksumIsOptional is set, a checksum value of -1 is.')
      ..comment('accepted.  It\'s a good idea to use a real checksum over an')
      ..comment('unreliable link, like a serial port.')
      ..comment('')
      ..comment('timeModulus lets you have timevalues in the feed that')
      ..comment('wrap; for example, a value of 65536 would be appropriate if')
      ..comment('you count time on your device in a 16 bit unsigned int')
      ..comment('The app uses 64 bit ints internally.')
      ..comment('')
      ..comment('if screenSwitchCommand is true, your feed must have an extra')
      ..comment('field before the checksum that gives the name of the screen')
      ..comment('you want shown at that time.  This allows the device being')
      ..comment('watched to cycle through different screens automatically.'),
    screens: [
      Screen(
          name: 'sliding',
          portrait: ScreenColumn<Color, Color>(content: [
            ScreenRow(content: [
              Spacer(1),
              Label(
                  text: 'Weather - Sliding', color: Color.whiteSmoke, flex: 4),
              Spacer(2),
              ScreenSwitchArrow(color: Color.white.darker(0.1))
            ]),
            Border(color: _borderColor),
            ScreenRow(content: [
              Border(color: _borderColor),
              DataWidget(displayer: _cityName.displayers[0]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _highTemp.displayers[1]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _highTemp.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _lowTemp.displayers[1]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _lowTemp.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _rainfall.displayers[1]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _rainfall.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
          ]),
          landscape: ScreenColumn<Color, Color>(content: [
            ScreenRow(content: [
              Spacer(1),
              Label(
                  text: 'Weather - Sliding', color: Color.whiteSmoke, flex: 6),
              Spacer(1),
              Border(color: _borderColor),
              ScreenColumn(flex: 8, content: [
                Border(color: _borderColor),
                DataWidget(displayer: _cityName.displayers[0], flex: 8),
              ]),
              Border(color: _borderColor),
              ScreenSwitchArrow(color: Color.white.darker(0.1), flex: 2),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 1, displayer: _lowTemp.displayers[1]),
              Border(color: _borderColor),
              DataWidget(flex: 1, displayer: _highTemp.displayers[1]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _lowTemp.displayers[2]),
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _rainfall.displayers[1]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _rainfall.displayers[2]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _highTemp.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
          ]))
        ..comment('This is a screen definition.  There can be multiple screen')
        ..comment('layouts, and the app can switch between the screens.')
        ..comment('Switching canb be done with a ScreenSwitchArrow widget,')
        ..comment('as is the case here, or the device can indicate which is')
        ..comment('the current screen with each data sample.'),
      Screen(
          name: 'rolling',
          portrait: ScreenColumn<Color, Color>(content: [
            ScreenRow(content: [
              Spacer(1),
              Label(
                  text: 'Weather - Rolling', color: Color.whiteSmoke, flex: 4),
              Spacer(2),
              ScreenSwitchArrow(color: Color.white.darker(0.1))
            ]),
            Border(color: _borderColor),
            ScreenRow(content: [
              Border(color: _borderColor),
              DataWidget(displayer: _cityName.displayers[0]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _highTemp.displayers[0]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _highTemp.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _lowTemp.displayers[0]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _lowTemp.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _rainfall.displayers[0]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _rainfall.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
          ]),
          landscape: ScreenColumn<Color, Color>(content: [
            ScreenRow(content: [
              Spacer(1),
              Label(
                  text: 'Weather - Rolling', color: Color.whiteSmoke, flex: 6),
              Spacer(1),
              Border(color: _borderColor),
              ScreenColumn(flex: 8, content: [
                Border(color: _borderColor),
                DataWidget(displayer: _cityName.displayers[0], flex: 8),
              ]),
              Border(color: _borderColor),
              ScreenSwitchArrow(color: Color.white.darker(0.1), flex: 2),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 1, displayer: _lowTemp.displayers[0]),
              Border(color: _borderColor),
              DataWidget(flex: 1, displayer: _highTemp.displayers[0]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 2, content: [
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _lowTemp.displayers[2]),
              Border(color: _borderColor),
              DataWidget(flex: 5, displayer: _rainfall.displayers[0]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _rainfall.displayers[2]),
              Border(color: _borderColor),
              DataWidget(flex: 2, displayer: _highTemp.displayers[2]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
          ]))
        ..comment(
            'This screen is like the one above, only the charts are rolling')
        ..comment('instead of sliding.'),
      Screen(
          name: 'long',
          portrait: ScreenColumn<Color, Color>(content: [
            ScreenRow(content: [
              Label(
                  flex: 5,
                  text: 'High Temperature for about 20 years',
                  color: Color.whiteSmoke),
              ScreenSwitchArrow(color: Color.white.darker(0.1))
            ]),
            Border(color: _borderColor),
            ScreenRow(flex: 3, content: [
              Border(color: _borderColor),
              DataWidget(displayer: _highTemp.displayers[3]),
              Border(color: _borderColor),
            ]),
            Border(color: _borderColor),
          ]))
        ..comment('This screen only has a definiton for one orientation.')
        ..comment('It\'s used for both.')
    ],
    sampleLog: []);

void main() {
  weather_demo.printJson();
}
