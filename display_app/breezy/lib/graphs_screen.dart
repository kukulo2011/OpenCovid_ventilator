import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:screen/screen.dart' show Screen;
import 'package:pedantic/pedantic.dart';
import 'rolling_chart.dart';
import 'dequeues.dart';
import 'read_device.dart';
import 'configure.dart' as config;

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

const _graphLabels = [
  GraphSelector(0, 'PRESSURE cmH2O', -10.0, 50.0),
  GraphSelector(1, 'FLOW l/min', -100.0, 100.0),
  GraphSelector(2, 'VOLUME ml', 0.0, 800.0),
];

final _displayedValues = [
  config.ValueBox(0, 'Ppeak', 'cmH2O', '##.#', Colors.orange.shade300),
  config.ValueBox(1, 'Pmean', 'cmH2O', '##.#', Colors.orange.shade300),
  config.ValueBox(2, 'PEEP', 'cmH2O', '##.#', Colors.orange.shade300),
  config.ValueBox(3, 'RR', 'b/min', '##.#', Colors.lightGreen),
  config.ValueBox(4, 'O2', null, '1##', Colors.lightGreen, postfix: '%'),
  config.ValueBox(5, 'Ti', 's', '##.##', Colors.lightGreen),
  config.ValueBox(6, 'I:E', null, '#.#', Colors.lightGreen,
      prefix: '1:'),
  config.ValueBox(7, 'MVi', 'l/min', '##.#', Colors.lightBlue),
  config.ValueBox(8, 'MVe', 'l/min', '##.#', Colors.lightBlue),
  config.ValueBox(9, 'VTi', null, '####', Colors.lightBlue),
  config.ValueBox(10, 'VTe', 'ml', '####', Colors.lightBlue)
];

class GraphSelector implements RollingChartSelector<ChartData> {
  final int _index;
  @override
  final String label;
  @override
  final double minValue;
  @override
  final double maxValue;

  const GraphSelector(this._index, this.label, this.minValue, this.maxValue);

  @override
  double getValue(ChartData data) => data.values?.elementAt(_index);
}

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

  GraphsScreen({Key key, @required DeviceDataSource dataSource})
      : this._dataSource = dataSource,
        super(key: key);

  @override
  _GraphsScreenState createState() => _GraphsScreenState(_dataSource);
}

class _GraphsScreenState extends State<GraphsScreen>
    implements DeviceDataListener {
  final DeviceDataSource _dataSource;
  DeviceData _current;
  final _chart = RollingDeque<ChartData>(
      500, 10, 0.5, (double time) => ChartData.dummy(time));
  static final _borderColor = Colors.grey[700];

  _GraphsScreenState(this._dataSource);

  @override
  void initState() {
    super.initState();
    _dataSource.start(this);
    unawaited(Screen.keepOn(true));
  }

  @override
  void dispose() {
    super.dispose();
    _dataSource.stop();
    unawaited(Screen.keepOn(false));
  }

  @override
  void processDeviceData(DeviceData d) {
    setState(() {
      _current = d;
      _chart.append(d.chart);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
        data: ThemeData.dark(),
        child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(children: <Widget>[
                Container(
                    decoration: const BoxDecoration(
                        border: Border(
                            top:
                                BorderSide(width: 2, color: Colors.transparent),
                            left:
                                BorderSide(width: 2, color: Colors.transparent),
                            right:
                                BorderSide(width: 2, color: Colors.transparent),
                            bottom: BorderSide(
                                width: 2, color: Colors.transparent))),
                    child: Container(
                        decoration: BoxDecoration(
                            border: Border(
                                right:
                                    BorderSide(width: 1, color: _borderColor),
                                bottom:
                                    BorderSide(width: 1, color: _borderColor))),
                        child: buildMainContents())),
                SizedBox(
                  width: 20,
                  height: 20,
                  child: IconButton(
                      icon: Icon(Icons.arrow_back),
                      iconSize: 14,
                      padding: EdgeInsets.all(0),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop()),
                )
              ]),
            )));
  }

  final Spacer foo = null;

  Row buildMainContents() {
    final windowData = _chart.window;
    return Row(
      children: [
        Expanded(
          flex: 8,
          child: Column(children: [
            Expanded(
                child: RollingChart<ChartData>(
                    selector: _graphLabels[0],
                    graphColor:
                        charts.MaterialPalette.deepOrange.shadeDefault.lighter,
                    windowSize: _chart.windowSize,
                    data: windowData)),
            Expanded(
                child: RollingChart<ChartData>(
                    selector: _graphLabels[1],
                    graphColor:
                        charts.MaterialPalette.green.shadeDefault.lighter,
                    windowSize: _chart.windowSize,
                    data: windowData)),
            Expanded(
                child: RollingChart<ChartData>(
                    selector: _graphLabels[2],
                    windowSize: _chart.windowSize,
                    data: windowData)),
          ]),
        ),
        Expanded(
          flex: 4,
          child: Column(children: [
            Expanded(
                child: Row(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                          child: _displayedValues[0].build(_current)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                        child: _displayedValues[2].build(_current)),
                    Expanded(
                        child: _displayedValues[1].build(_current)),
                  ]),
                )
              ],
            )),
            Expanded(
                child: Row(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                          child: _displayedValues[3].build(_current)),
                      Expanded(
                          child: _displayedValues[4].build(_current)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                        child: _displayedValues[5].build(_current)),
                    Expanded(
                        child: _displayedValues[6].build(_current)),
                  ]),
                )
              ],
            )),
            Expanded(
                child: Row(
              children: <Widget>[
                Expanded(
                  flex: 4,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                          child: _displayedValues[7].build(_current)),
                      Expanded(
                          child: _displayedValues[8].build(_current)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                        child: _displayedValues[9].build(_current)),
                    Expanded(
                        child: _displayedValues[10].build(_current)),
                  ]),
                )
              ],
            )),
          ]),
        )
      ],
    );
  }
}
