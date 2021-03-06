import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:screen/screen.dart' show Screen;
import 'package:pedantic/pedantic.dart';
import 'configure_a.dart';
import 'value_box.dart';
import 'rolling_chart.dart';
import 'dart:async';
import 'package:collection/collection.dart' show ListEquality;
import 'configure.dart' as config;
import 'configure_a.dart' as config;
import 'data_types.dart';
import 'read_device.dart';
import 'main.dart' show Log, BreezyGlobals, showErrorDialog;
import 'fitted_text.dart';

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

///
/// The screen where all the fancy graphs are shown.  This is the primary
/// screen for this app.
///
/// All the state is put at the top for simplicity.  At least in the initial app,
/// everything is updated at the same time, so it doesn't really make sense to
/// try to optimize display if only part of the screen changes.

class GraphsScreen extends StatelessWidget {
  final DeviceDataSource _dataSource;
  final BreezyGlobals _globals;
  GraphsScreen(
      {Key key,
      @required DeviceDataSource dataSource,
      @required BreezyGlobals globals})
      : this._dataSource = dataSource,
        this._globals = globals,
        super(key: key);

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: <Widget>[
          Container(
              decoration: const BoxDecoration(
                  border: Border(
                      top: BorderSide(width: 2, color: Colors.transparent),
                      left: BorderSide(width: 2, color: Colors.transparent),
                      right: BorderSide(width: 2, color: Colors.transparent),
                      bottom: BorderSide(width: 2, color: Colors.transparent))),
              child: _GraphsScreen(dataSource: _dataSource, globals: _globals)),
          SizedBox(
              width: 20,
              height: 20,
              child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  iconSize: 14,
                  padding: const EdgeInsets.all(0),
                  tooltip: 'Back',
                  onPressed: () {})),
          SizedBox(
            width: 50,
            height: 50,
            child: FlatButton(
                color: Colors.transparent,
                child: Container(),
                padding: const EdgeInsets.all(0),
                onPressed: () {
                  Navigator.of(context).pop();
                }),
          ),
          // We show a tiny arrow, but make the touch area bigger.
        ]),
      ));
}

class _GraphsScreen extends StatefulWidget {
  final DeviceDataSource _dataSource;
  final BreezyGlobals _globals;

  _GraphsScreen(
      {Key key,
      @required DeviceDataSource dataSource,
      @required BreezyGlobals globals})
      : this._dataSource = dataSource,
        this._globals = globals,
        super(key: key);

  @override
  _GraphsScreenState createState() => _GraphsScreenState(_dataSource, _globals);
}

/// Where we capture all of the data currently being displayed.
class HistoricalData {
  DeviceData _current;
  final List<WindowedData<ChartData>> _deques;
  void Function() advanceScreen;

  HistoricalData(config.DataFeed feed) : this._deques = feed.createDeques();

  DeviceData get current => _current;

  void receive(DeviceData data) {
    _current = data;
    for (final deque in _deques) {
      deque.append(data.chart);
    }
  }

  WindowedData<ChartData> getDeque(int index) => _deques[index];
}

class _GraphsScreenState extends State<_GraphsScreen>
    implements DeviceDataListener {
  static int _screenOnCount = 0;
  final DeviceDataSource _dataSource;
  final BreezyGlobals globals;
  final HistoricalData _data;
  config.Screen screen;
  int screenNum;
  final _WidgetBuilder _builder;
  bool _disposed = false;
  bool _popCalled = false;
  Exception _lastError;
  DateTime _lastErrorTime;

  _GraphsScreenState(this._dataSource, this.globals)
      : _data = HistoricalData(globals.configuration.feed),
        _builder = _WidgetBuilder(globals.configuration.feed) {
    _data.advanceScreen = advanceScreen;
    _builder.data = _data;
  }

  @override
  void initState() {
    _screenOnCount++;
    super.initState();
    screenNum = 0;
    screen = globals.configuration.screens[screenNum];
    unawaited(() async {
      // Execute this in a microtask.  The data source reserves the right
      // to take some time before it completes its future, so that it can
      // report an error, if needed.
      await Screen.keepOn(true);
      try {
        await _dataSource.start(this);
      } catch (ex, st) {
        if (st == null) {
          print(ex);
        } else {
          print(st);
        }
        if (!_disposed) {
          await showErrorDialog(context, "Error opening connection", ex);
        }
        if (!_disposed && !_popCalled) {
          _popCalled = true;
          Navigator.of(context).pop();
        }
      }
    }());
  }

  @override
  void dispose() {
    super.dispose();
    _disposed = true;
    _dataSource.stop();
    _screenOnCount--;
    if (_screenOnCount == 0) {
      unawaited(Screen.keepOn(false));
    }
  }

  /// Advance to the next screen in our configuration's list of screens.
  void advanceScreen() {
    setState(() {
      screenNum = (screenNum + 1) % globals.configuration.screens.length;
      screen = globals.configuration.screens[screenNum];
    });
  }

  @override
  Future<void> processDeviceData(DeviceData d) async {
    if (d.newScreen != '') {
      int sn = globals.configuration.getScreenNum(d.newScreen);
      if (sn != null) {
        screen = globals.configuration.screens[sn];
        screenNum = sn;
      } else {
        Log.writeln('Screen "${d.newScreen}" not found');
      }
    }
    setState(() {
      _data.receive(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) {
      if (orientation == Orientation.portrait) {
        screen.portrait.accept(_builder);
      } else {
        screen.landscape.accept(_builder);
      }
      final r = _builder.built;
      _builder.built = null;
      return r;
    });
  }

  @override
  Future<void> processNewConfiguration(
      config.AndroidBreezyConfiguration newConfig,
      DeviceDataSource Function() nextSourceFunction) async {
    if (globals.configuration is JsonBreezyConfiguration &&
        globals.configuration.name == newConfig.name) {
      // They might be the same.  If they are, no reason to save something
      // we already have, and annoy the user by "switching" to what they're
      // already seeing.
      //
      // It's a bit of a sleazy shortcut, but just generating the JSON
      // to see if it's the same is easy and realiable.  This isn't a
      // performance-critical operation, and actually implementing a
      // deep equivalence test is fairly tedious and error-prone.  We compare
      // the gzipped compact JSON.
      final List<int> oldL = await globals.configuration.getCompactJson();
      final List<int> newL = await newConfig.getCompactJson();
      if (ListEquality<int>().equals(oldL, newL)) {
        Scaffold.of(context).showSnackBar(SnackBar(
            content: Text(
                'Device sent a copy of the current configuration "${newConfig.name}"'),
            duration: Duration(seconds: 5)));
        return;
      }
    }
    await newConfig.save();
    globals.configuration = newConfig;
    globals.settings.configurationName = newConfig.name;
    await globals.settings.write();
    final DeviceDataSource nextSource = nextSourceFunction();
    if (!_popCalled) {
      _popCalled = true;
      Navigator.of(context).pop(nextSource);
    }
  }

  @override
  Future<void> processError(Exception ex) async {
    Scaffold.of(context).showSnackBar(SnackBar(
        content: Text('Connection error:  $ex'),
        duration: Duration(seconds: 30)));
    _lastError = ex;
    _lastErrorTime = DateTime.now();
  }

  @override
  Future<void> processEOF() async {
    if (_lastErrorTime != null &&
        DateTime.now().difference(_lastErrorTime).inSeconds > 30) {
      // Stale notification.
      _lastError = null;
    }
    if (!_popCalled) {
      _popCalled = true;
      Navigator.of(context).pop(_lastError);
      ;
    }
  }
}

/// The visitor we send to the current Screen to build our Flutter widget
/// tree on every frame of animation.
class _WidgetBuilder
    implements config.ScreenWidgetVisitor<Color, charts.Color> {
  HistoricalData data;
  Widget built;
  List<double Function(ChartData d)> _selectors;

  _WidgetBuilder(config.DataFeed feed) {
    _selectors = List<double Function(ChartData d)>(feed.chartedValues.length);
    for (int i = 0; i < _selectors.length; i++) {
      _selectors[i] = (ChartData d) => d.values?.elementAt(i);
    }
  }

  Widget _wrapIfNeeded(config.ScreenWidget<Color, charts.Color> c, Widget w) {
    if (c.hasParent && c.flex != null) {
      return Expanded(flex: c.flex, child: w);
    } else {
      return w;
    }
  }

  List<Widget> _buildChildren(config.ScreenContainer<Color, charts.Color> c) {
    final result = List<Widget>(c.content.length);
    for (int i = 0; i < result.length; i++) {
      c.content[i].accept(this);
      result[i] = built;
    }
    return result;
  }

  @override
  void visitColumn(config.ScreenColumn<Color, charts.Color> w) {
    built = _wrapIfNeeded(
        w,
        Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _buildChildren(w)));
  }

  @override
  void visitRow(config.ScreenRow<Color, charts.Color> w) {
    built = _wrapIfNeeded(
        w,
        Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: _buildChildren(w)));
  }

  @override
  void visitLabel(config.Label<Color, charts.Color> w) {
    built =
        _wrapIfNeeded(w, FittedText(w.text, style: TextStyle(color: w.color)));
  }

  @override
  void visitSpacer(config.Spacer<Color, charts.Color> w) {
    built = Spacer(flex: w.flex);
  }

  @override
  visitBorder(config.Border<Color, charts.Color> w) {
    final constraints = w.parentIsRow
        ? BoxConstraints.expand(width: w.width)
        : BoxConstraints.expand(height: w.width);
    // We want the line to be w.width pixles wide.  If our parent is a row,
    // we're a veritcal line, so our width needs to be fixed.
    built = _wrapIfNeeded(
        w,
        Container(
            constraints: constraints,
            width: w.width,
            height: w.width,
            color: w.color));
  }

  @override
  void visitSwitchArrow(config.ScreenSwitchArrow<Color, charts.Color> w) {
    built = Expanded(
        flex: w.flex,
        child: Container(
          constraints: BoxConstraints.expand(),
          child: FittedBox(
              fit: BoxFit.contain,
              child: IconButton(
                  icon: Icon(Icons.navigate_next),
                  tooltip: 'Next Screen',
                  color: w.color,
                  onPressed: data.advanceScreen)),
        ));
  }

  @override
  void visitTimeChart(config.TimeChart<Color, charts.Color> w) {
    final WindowedData<ChartData> deque = data.getDeque(w.dequeIndex);
    assert(deque.windowSize == w.timeSpan);
    built = TimeChart<ChartData>(
        key: ObjectKey(w),
        selector: _selectors[w.valueIndex],
        label: w.label,
        labelHeightFactor: w.labelHeightFactor,
        numTicks: w.displayedTimeTicks,
        minValue: w.minValue,
        maxValue: w.maxValue,
        graphColor: w.color,
        data: deque);
  }

  @override
  void visitValueBox(config.ValueBox<Color, charts.Color> w) {
    built = ValueBox(
        key: ObjectKey(w),
        value: data.current?.displayedValues?.elementAt(w.valueIndex),
        label: w.label,
        labelHeightFactor: w.labelHeightFactor,
        format: w.format,
        alignment: w.alignment,
        color: w.color,
        units: w.units,
        prefix: w.prefix,
        postfix: w.postfix);
  }

  @override
  void visitDataWidget(config.DataWidget<Color, charts.Color> w) {
    w.displayer.accept(this);
    built = _wrapIfNeeded(w, built);
  }
}
