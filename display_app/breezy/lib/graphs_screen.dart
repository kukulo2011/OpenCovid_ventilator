import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'dart:collection' show DoubleLinkedQueue;
import 'dart:async' show Timer;

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

/**
 * The screen where all the fancy graphs are shown.  This is the primary
 * screen for this app.
 *
 * All the state is put at the top for simplicity.  At least in the initial app,
 * everything is updated at the same time, so it doesn't really make sense to
 * try to optimize display if only part of the screen changes.
 */
class GraphsScreen extends StatefulWidget {
  GraphsScreen({Key key}) : super(key: key);

  @override
  _GraphsScreenState createState() => _GraphsScreenState();
}

class _GraphsScreenState extends State<GraphsScreen> {

  double _currTime = 0;
  final _data = DoubleLinkedQueue<Data>();
  static final _random = Random();
  static final _gap = 0.5;  // # of seconds of gap in rolling chart
  static Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 20), (_) => _tick());
    _data.add(Data(_gap / 2, null));
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
  }

  void _tick() {
    final frobbed = _currTime.remainder(3.7);
    final double v = _random.nextDouble() * 0.5 + ( frobbed < 1.5 ? 1.0 : 7.0 );
    setState(() {
      _data.lastEntry().element = Data(_currTime, v);
      _data.add(Data(_currTime + _gap / 2, null));
      while (_data.first.time < _currTime - (10 - _gap)) {
        _data.removeFirst();
      }
    });
    _currTime += 0.020;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(width: 30, color: Colors.transparent),
                    left: BorderSide(width: 10, color: Colors.transparent),
                    right: BorderSide(width: 10, color: Colors.transparent),
                    bottom: BorderSide(width: 10, color: Colors.transparent))),
            child: RollingChart(
              maxValue: 10,
              data: _data.toList(growable: false)
            )));
  }
}

/**
 * A rolling chart.  The X axis is time, from 0 to 10 seconds.  Numbers
 * aren't given, and there's a 1/2 second black "gap" marking the current
 * time.
 */
class RollingChart extends StatelessWidget {

  final double _maxValue;
  final List<Data> _data;

  RollingChart({@required double maxValue, @required List<Data> data}) :
      this._maxValue = maxValue, this._data = data {
    _data.sort((a, b) {
      final av = a.time.remainder(10.0);
      final bv = b.time.remainder(10.0);
      if (av < bv) {
        return -1;
      } else if (av == bv) {
        return 0;
      } else {
        return 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return charts.LineChart(<charts.Series<Data, double>>[
      charts.Series<Data, double>(
        id: 'set_scale',
        colorFn: (_, __) => charts.Color.transparent,
        domainFn: (d, _) => d.time,
        measureFn: (d, _) => d.value,
        data: [Data(0, _maxValue)]    // Hack to keep Ymax constant
      ),
      charts.Series<Data, double>(
          id: 'data',
          colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
          domainFn: (d, _) => d.time.remainder(10.0),
          measureFn: (d, _) => d.value,
          data: _data
      )],
      domainAxis: charts.NumericAxisSpec(
        // Eventually, fill in to get thicker ticks:
        //      renderSpec: charts.SmallTickRendererSpec<double>(),
        tickProviderSpec: charts.StaticNumericTickProviderSpec([
          charts.TickSpec(0.0, label: ''),
          charts.TickSpec(1.0, label: ''),
          charts.TickSpec(2.0, label: ''),
          charts.TickSpec(3.0, label: ''),
          charts.TickSpec(4.0, label: ''),
          charts.TickSpec(5.0, label: ''),
          charts.TickSpec(6.0, label: ''),
          charts.TickSpec(7.0, label: ''),
          charts.TickSpec(8.0, label: ''),
          charts.TickSpec(9.0, label: ''),
          charts.TickSpec(10.0, label: '')
        ])
      ),
      animate: false);
  }
}

// A temporary Data class.  The final program will have one instance for
// each time value, and a selector function.
class Data {
  final double time;
  final double value;

  Data(this.time, this.value);
}

