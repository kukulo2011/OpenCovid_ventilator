import 'package:flutter/material.dart';
import 'package:screen/screen.dart' show Screen;
import 'package:pedantic/pedantic.dart';
import 'dart:async';
import 'configure.dart' as config;
import 'deques.dart';
import 'read_device.dart';
import 'main.dart' show Log;

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
///
class GraphsScreen extends StatefulWidget {
  final DeviceDataSource _dataSource;
  final config.BreezyConfiguration _config;

  GraphsScreen(
      {Key key,
      @required DeviceDataSource dataSource,
      @required config.BreezyConfiguration config})
      : this._dataSource = dataSource,
        this._config = config,
        super(key: key);

  @override
  _GraphsScreenState createState() => _GraphsScreenState(_dataSource, _config.feed);
}

class HistoricalData {
  DeviceData _current;
  final List<WindowedData<ChartData>> _deques;

  HistoricalData(config.DataFeed feed) :
    this._deques = feed.createDeques();

  DeviceData get current => _current;

  void receive(DeviceData data) {
    _current = data;
    for (final deque in _deques) {
      deque.append(data.chart);
    }
  }

  WindowedData<ChartData> getDeque(int index) => _deques[index];
}

class _GraphsScreenState extends State<GraphsScreen>
    implements DeviceDataListener {
  final DeviceDataSource _dataSource;
  final HistoricalData _data;
  static final _borderColor = Colors.grey[700];
  config.Screen screen;
  Completer<void> _waitingForBuild;
  DateTime _lastBuild = DateTime.now(); // never null

  _GraphsScreenState(this._dataSource, config.DataFeed feed) :
    this._data = HistoricalData(feed);

  @override
  void initState() {
    super.initState();
    screen = widget._config.screens[0]; // TODO - more screens?
    _dataSource.start(this);
    unawaited(Screen.keepOn(true));
  }

  @override
  void dispose() {
    super.dispose();
    _dataSource.stop();
    unawaited(Screen.keepOn(false));
    _notifyBuild();
  }

  void _notifyBuild() {
    if (_waitingForBuild != null) {
      final w = _waitingForBuild;
      _waitingForBuild = null;
      w.complete(null);
    }
    _lastBuild = DateTime.now();
  }

  @override
  Future<void> processDeviceData(DeviceData d) async {
    setState(() {
      _data.receive(d);
    });
    final delay = DateTime.now().difference(_lastBuild).inMilliseconds;
    if (delay > 500 && _dataSource.running) {
      final w = Completer<void>();
      _waitingForBuild = w;
      Log.writeln('Screen unbuilt for $delay ms:  Waiting for UI build.');
      await w.future;
    }
  }

  @override
  Widget build(BuildContext context) {
    _notifyBuild();
    return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(children: <Widget>[
            Container(
                decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(width: 2, color: Colors.transparent),
                        left: BorderSide(width: 2, color: Colors.transparent),
                        right: BorderSide(width: 2, color: Colors.transparent),
                        bottom:
                            BorderSide(width: 2, color: Colors.transparent))),
                child: Container(
                    decoration: BoxDecoration(
                        border: Border(
                            right: BorderSide(width: 1, color: _borderColor),
                            bottom: BorderSide(width: 1, color: _borderColor))),
                    child: buildMainContents())),
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
                  onPressed: () => Navigator.of(context).pop()),
            ),
            // We show a tiny arrow, but make the touch area bigger.
          ]),
        ));
  }

  Widget buildMainContents() {
    return OrientationBuilder(
        builder: (BuildContext context, Orientation orientation) =>
            orientation == Orientation.portrait
                ? screen.portrait.build(_data)
                : screen.landscape.build(_data));
  }
}
