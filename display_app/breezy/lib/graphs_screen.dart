import 'dart:math';
import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'rolling_deque.dart';

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
  GraphsScreen({Key key}) : super(key: key);

  @override
  _GraphsScreenState createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {
  double _currTime = 0;
  final _data =
      RollingDeque(500, 10, 0.5, (double time) => Data(time, null, null, null));
  static final _random = Random();
  static Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 20), (_) => _tick());
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  void _tick() {
    final frobbed = _currTime.remainder(3.7);
    final double v1 = _random.nextDouble() * 0.5 + (frobbed < 1.5 ? 1.0 : 7.0);
    final double v2 = (frobbed < 1.5 ? frobbed * 5 : 2.0);
    final double v3 = 5 + 6 * sin(_currTime); // Some out of range
    setState(() {
      _data.append(Data(_currTime, v1, v2, v3));
    });
    _currTime += 0.020;
  }

  @override
  Widget build(BuildContext context) {
    final windowData = _data.rollingWindow.toList(growable: false);
    return Scaffold(
        body: SafeArea(
      child: Container(
          decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(width: 5, color: Colors.transparent),
                  left: BorderSide(width: 5, color: Colors.transparent),
                  right: BorderSide(width: 5, color: Colors.transparent),
                  bottom: BorderSide(width: 0, color: Colors.transparent))),
          child: Row(
            children: [
              Expanded(
                child: Column(children: [
                  Expanded(
                      child: RollingChart<Data>(
                          maxValue: 10,
                          windowSize: _data.windowSize,
                          data: windowData,
                          dataSelector: (d) => d.v1)),
                  Expanded(
                      child: RollingChart<Data>(
                          maxValue: 10,
                          windowSize: _data.windowSize,
                          data: windowData,
                          dataSelector: (d) => d.v2)),
                  Expanded(
                      child: RollingChart<Data>(
                          maxValue: 10,
                          windowSize: _data.windowSize,
                          data: windowData,
                          dataSelector: (d) => d.v3)),
                ]),
              ),
              Column(children: [
                Text('THIS AREA TBD'),
                Text('THIS AREA TBD'),
                Text('THIS AREA TBD'),
                Text('THIS AREA TBD'),
              ])
            ],
          )),
    ));
  }
}

/// A rolling chart.  The X axis is time, from 0 to windowSize.  Numbers
/// aren't given, and there's a 1/2 second black "gap" marking the current
/// time.
class RollingChart<D extends RollingDequeData> extends StatelessWidget {
  final double _maxValue;
  final double _windowSize;
  final List<D> _data;
  final double Function(D) _dataSelector;

  /// [data] must be sorted by time.remainder(window size).
  RollingChart(
      {@required double maxValue,
      @required double windowSize,
      @required List<D> data,
      @required double Function(D) dataSelector})
      : this._maxValue = maxValue,
        this._windowSize = windowSize,
        this._data = data,
        this._dataSelector = dataSelector;

  @override
  Widget build(BuildContext context) {
    final numTicks = max(0, _windowSize.floor()) + 1;
    final tickSpecs = List<charts.TickSpec<double>>(numTicks);
    for (int i = 0; i < numTicks; i++) {
      tickSpecs[i] = charts.TickSpec(i.toDouble(), label: '');
    }
    return charts.LineChart(<charts.Series<D, double>>[
      charts.Series<D, double>(
          id: 'set_scale', // Hack to keep Ymax constant
          colorFn: (_, __) => charts.Color.transparent,
          domainFn: (d, _) => 0,
          measureFn: (d, _) => _maxValue,
          data: [null]),
      charts.Series<D, double>(
          id: 'data',
          colorFn: (d, __) {
            final v = _dataSelector(d);
            if (v == null) {
              return charts.MaterialPalette.blue.shadeDefault;
            } else if (v < 0.0 || v > _maxValue) {
              return charts.MaterialPalette.red.shadeDefault;
            } else {
              return charts.MaterialPalette.blue.shadeDefault;
            }
          },
          domainFn: (d, _) => d.time.remainder(_windowSize),
          measureFn: (d, _) {
            final v = _dataSelector(d);
            if (v == null) {
              return null;
            } else if (v < 0.0) {
              return 0.0;
            } else if (v > _maxValue) {
              return _maxValue;
            } else {
              return v;
            }
          },
          data: _data)
    ],
        domainAxis: charts.NumericAxisSpec(
            // Eventually, fill in to get thicker ticks:
            //      renderSpec: charts.SmallTickRendererSpec<double>(),
            tickProviderSpec: charts.StaticNumericTickProviderSpec(tickSpecs)),
        animate: false);
  }
}

// A temporary Data class.  The final program will have one instance for
// each time value, and a selector function.
class Data implements RollingDequeData {
  @override
  final double time;
  final double v1;
  final double v2;
  final double v3;

  Data(this.time, this.v1, this.v2, this.v3);
}
