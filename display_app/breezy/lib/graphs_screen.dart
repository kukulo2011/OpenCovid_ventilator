import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:screen/screen.dart' show Screen;
import 'package:pedantic/pedantic.dart';
import 'rolling_chart.dart';
import 'rolling_deque.dart';
import 'value_box.dart';
import 'read_device.dart';

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
  _GraphSelector('PRESSURE cmH2O', -10.0, 50.0, 0),
  _GraphSelector('FLOW l/min', -100.0, 100.0, 1),
  // TODO:  Spec says -999 to 999, but the sample data is different.
  _GraphSelector('VOLUME ml', 0.0, 800.0, 2),
  // TODO:  Spec claims volum is 0..9999, but the sample data is nowhere
  //        near that.  And ten liters of air is a lot!
];

final _displayedValues = [
  DisplayedValueSelector('Ppeak', 'cmH2O', '##.#', Colors.orange.shade300, 0),
  DisplayedValueSelector('Pmean', 'cmH2O', '##.#', Colors.orange.shade300, 1),
  DisplayedValueSelector('PEEP', 'cmH2O', '##.#', Colors.orange.shade300, 2),
  DisplayedValueSelector('RR', 'b/min', '##.#', Colors.lightGreen, 3),
  DisplayedValueSelector('O2', '     %', '1##', Colors.lightGreen, 4),
  DisplayedValueSelector('Ti', 's', '##.#', Colors.lightGreen, 5),
  DisplayedValueSelector('I:E', null, '##.#', Colors.lightGreen, 6),
  DisplayedValueSelector('MVi', 'l/min', '##.#', Colors.lightBlue, 7),
  DisplayedValueSelector('MVe', 'l/min', '##.#', Colors.lightBlue, 8),
  DisplayedValueSelector('VTi', null, '####', Colors.lightBlue, 9),
  DisplayedValueSelector('VTe', 'ml', '####', Colors.lightBlue, 10)
];

class _GraphSelector implements RollingChartSelector<DeviceData> {
  @override
  final String label;
  @override
  final double minValue;
  @override
  final double maxValue;
  final int _index;

  const _GraphSelector(this.label, this.minValue, this.maxValue, this._index);

  @override
  double getValue(DeviceData data) => data.chartedValues?.elementAt(_index);
}

class DisplayedValueSelector {
  final String label;
  final String units;
  final String format;
  final Color color;
  final int index;
  DisplayedValueSelector(
      this.label, this.units, this.format, this.color, this.index);
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
  final _data =
      RollingDeque(500, 10, 0.5, (double time) => DeviceData.dummy(time));
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
    setState(() => _data.append(d));
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

  Row buildMainContents() {
    final windowData = _data.rollingWindow;
    final current = _data.current;
    return Row(
      children: [
        Expanded(
          flex: 8,
          child: Column(children: [
            Expanded(
                child: RollingChart<DeviceData>(
                    selector: _graphLabels[0],
                    graphColor:
                        charts.MaterialPalette.deepOrange.shadeDefault.lighter,
                    windowSize: _data.windowSize,
                    data: windowData)),
            Expanded(
                child: RollingChart<DeviceData>(
                    selector: _graphLabels[1],
                    graphColor:
                        charts.MaterialPalette.green.shadeDefault.lighter,
                    windowSize: _data.windowSize,
                    data: windowData)),
            Expanded(
                child: RollingChart<DeviceData>(
                    selector: _graphLabels[2],
                    windowSize: _data.windowSize,
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
                          child: _DisplayedValueBox(
                              selector: _displayedValues[0], data: current)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                        child: _DisplayedValueBox(
                            selector: _displayedValues[2], data: current)),
                    Expanded(
                        child: _DisplayedValueBox(
                            selector: _displayedValues[1], data: current)),
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
                          child: _DisplayedValueBox(
                              selector: _displayedValues[3], data: current)),
                      Expanded(
                          child: _DisplayedValueBox(
                              selector: _displayedValues[4], data: current)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                        child: _DisplayedValueBox(
                            selector: _displayedValues[5], data: current)),
                    Expanded(
                        child: _DisplayedValueBox(
                            selector: _displayedValues[6], data: current)),
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
                          child: _DisplayedValueBox(
                              selector: _displayedValues[7], data: current)),
                      Expanded(
                          child: _DisplayedValueBox(
                              selector: _displayedValues[8], data: current)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(children: [
                    Expanded(
                        child: _DisplayedValueBox(
                            selector: _displayedValues[9], data: current)),
                    Expanded(
                        child: _DisplayedValueBox(
                            selector: _displayedValues[10], data: current)),
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

class _DisplayedValueBox extends ValueBox {
  _DisplayedValueBox({DisplayedValueSelector selector, DeviceData data})
      : super(
            value: data?.displayedValues?.elementAt(selector.index),
            label: selector.label,
            format: selector.format,
            color: selector.color,
            units: selector.units);
}
