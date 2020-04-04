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
  _GraphSelector(0, 'PRESSURE cmH2O', -10.0, 50.0),
  _GraphSelector(1, 'FLOW l/min', -100.0, 100.0),
  // TODO:  Spec says -999 to 999, but the sample data is different.
  _GraphSelector(2, 'VOLUME ml', 0.0, 800.0),
  // TODO:  Spec claims volum is 0..9999, but the sample data is nowhere
  //        near that.  And ten liters of air is a lot!
];

final _displayedValues = [
  DisplayedValueSelector(0, 'Ppeak', 'cmH2O', '##.#', Colors.orange.shade300),
  DisplayedValueSelector(1, 'Pmean', 'cmH2O', '##.#', Colors.orange.shade300),
  DisplayedValueSelector(2, 'PEEP', 'cmH2O', '##.#', Colors.orange.shade300),
  DisplayedValueSelector(3, 'RR', 'b/min', '##.#', Colors.lightGreen),
  DisplayedValueSelector(4, 'O2', null, '1##', Colors.lightGreen,
      postfix: '%'),
  DisplayedValueSelector(5, 'Ti', 's', '##.##', Colors.lightGreen),
  DisplayedValueSelector(6, 'I:E', null, '#.#', Colors.lightGreen,
      prefix: '1:'),
  DisplayedValueSelector(7, 'MVi', 'l/min', '##.#', Colors.lightBlue),
  DisplayedValueSelector(8, 'MVe', 'l/min', '##.#', Colors.lightBlue),
  DisplayedValueSelector(9, 'VTi', null, '####', Colors.lightBlue),
  DisplayedValueSelector(10, 'VTe', 'ml', '####', Colors.lightBlue)
];

class _GraphSelector implements RollingChartSelector<DeviceData> {
  final int _index;
  @override
  final String label;
  @override
  final double minValue;
  @override
  final double maxValue;

  const _GraphSelector(this._index, this.label, this.minValue, this.maxValue);

  @override
  double getValue(DeviceData data) => data.chartedValues?.elementAt(_index);
}

class DisplayedValueSelector {
  final int index;
  final String label;
  final String units;
  final String format;
  final Color color;
  final String prefix;
  final String postfix;
  DisplayedValueSelector(
      this.index, this.label, this.units, this.format, this.color,
      {this.prefix, this.postfix});
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
            units: selector.units,
            prefix: selector.prefix,
            postfix: selector.postfix);
}
