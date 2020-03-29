import 'dart:math';
import 'dart:async' show Timer;
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:screen/screen.dart' show Screen;
import 'package:pedantic/pedantic.dart';
import 'rolling_chart.dart';
import 'rolling_deque.dart';
import 'value_box.dart';

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
  static final _borderColor = Colors.grey[700];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 20), (_) => _tick());
    unawaited(Screen.keepOn(true));
  }

  @override
  void dispose() {
    super.dispose();
    _timer.cancel();
    unawaited(Screen.keepOn(false));
  }

  void _tick() {
    final frobbed = _currTime.remainder(3.7);
    final double v1 = _random.nextDouble() * 0.5 + (frobbed < 1.5 ? 1.0 : 7.0);
    final double v2 = (frobbed < 1.5 ? frobbed * 5 : 2.0);
    final double v3 = 6 * sin(_currTime); // Some out of range
    setState(() {
      _data.append(Data(_currTime, v1, v2, v3));
    });
    _currTime += 0.020;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData.dark(),
        child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Container(
                  decoration: const BoxDecoration(
                      border: Border(
                          top: BorderSide(width: 2, color: Colors.transparent),
                          left: BorderSide(width: 2, color: Colors.transparent),
                          right:
                              BorderSide(width: 2, color: Colors.transparent),
                          bottom:
                              BorderSide(width: 2, color: Colors.transparent))),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(width: 1, color: _borderColor),
                        bottom: BorderSide(width: 1, color: _borderColor))),
                    child: buildMainContents())),
            )));
  }

  Row buildMainContents() {
    final windowData = _data.rollingWindow.toList(growable: false);
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(children: [
            Expanded(
                child: RollingChart<Data>(
                    label: 'PRESSURE mbar',
                    graphColor:
                        charts.MaterialPalette.deepOrange.shadeDefault.lighter,
                    maxValue: 10,
                    windowSize: _data.windowSize,
                    data: windowData,
                    dataSelector: (d) => d.v1)),
            Expanded(
                child: RollingChart<Data>(
                    label: 'FLOW l/s',
                    graphColor:
                        charts.MaterialPalette.green.shadeDefault.lighter,
                    maxValue: 10,
                    windowSize: _data.windowSize,
                    data: windowData,
                    dataSelector: (d) => d.v2)),
            Expanded(
                child: RollingChart<Data>(
                    label: 'VOLUME ml',
                    maxValue: 5,
                    minValue: -5,
                    windowSize: _data.windowSize,
                    data: windowData,
                    dataSelector: (d) => d.v3)),
          ]),
        ),
        Expanded(
          flex: 3,
          child: Column(children: [
            Expanded(child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(child: ValueBox(value: 0, label: 'Ppeak', units: 'mbar')),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: ValueBox(value: 0, label: 'PEEP')),
                      Expanded(child: ValueBox(value: 0, label: 'Pmean'))
                    ]
                  ),
                )
              ],
            )),
            Expanded(child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(child: ValueBox(value: 0, label: 'RR', units: 'b/min')),
                      Expanded(child: ValueBox(value: 0, label: 'O2', units: '%')),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: ValueBox(value: 0, label: 'Ti')),
                      Expanded(child: ValueBox(value: 0, label: 'I:E'))
                    ]
                  ),
                )
              ],
            )),
            Expanded(child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Expanded(child: ValueBox(value: 0, label: 'MVi', units: 'l/min')),
                      Expanded(child: ValueBox(value: 0, label: 'MVe', units: 'l/min')),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: ValueBox(value: 0, label: 'VTi', units: 'ml')),
                      Expanded(child: ValueBox(value: 0, label: 'VTe', units: 'ml'))
                    ]
                  ),
                )
              ],
            )),
          ]),
        )
      ],
    );
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
