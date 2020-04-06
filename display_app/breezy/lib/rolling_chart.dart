import 'dart:math';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'dequeues.dart';

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

/// A rolling chart.  The X axis is time, from 0 to windowSize.  Numbers
/// aren't given, and there's a 1/2 second black "gap" marking the current
/// time.
class RollingChart<D extends TimedData> extends StatelessWidget {
  final double windowSize;
  final List<D> _data;
  final RollingChartSelector _selector;
  final charts.Color graphColor;
  final charts.Color graphOutOfRangeColor;

  /// [data] must be sorted by time.remainder(window size).
  RollingChart(
      {@required this.windowSize,
      @required List<D> data,
      @required RollingChartSelector selector,
      charts.Color graphColor,
      charts.Color graphOutOfRangeColor})
      : this._data = data,
        this._selector = selector,
        this.graphColor = (graphColor == null) ? defaultGraphColor : graphColor,
        this.graphOutOfRangeColor = (graphOutOfRangeColor == null)
            ? charts.MaterialPalette.red.shadeDefault
            : graphOutOfRangeColor;

  static charts.Color defaultGraphColor =
      charts.MaterialPalette.blue.shadeDefault.lighter;
  static charts.Color defaultGraphOutOfRangeColor =
      charts.MaterialPalette.red.shadeDefault;
  static final _borderColor = Colors.grey[700];

  @override
  Widget build(BuildContext context) {
    final numTicks = max(0, windowSize.floor()) + 1;
    final tickSpecs = List<charts.TickSpec<double>>(numTicks);
    for (int i = 0; i < numTicks; i++) {
      tickSpecs[i] = charts.TickSpec(i.toDouble(), label: '');
    }

    return Container(
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(width: 1, color: _borderColor),
                left: BorderSide(width: 1, color: _borderColor))),
        child: Stack(
          children: <Widget>[
            Row(children: [
              SizedBox.fromSize(size: Size(30, 1)),
              Text(_selector.label, style: TextStyle(color: Colors.grey[400])),
            ]),
            charts.LineChart(<charts.Series<D, double>>[
              charts.Series<D, double>(
                  id: 'data',
                  colorFn: (d, __) {
                    final v = _selector.getValue(d);
                    if (v == null) {
                      return graphColor; // doesn't matter
                    } else if (v < _selector.minValue ||
                        v > _selector.maxValue) {
                      return graphOutOfRangeColor;
                    } else {
                      return graphColor;
                    }
                  },
                  domainFn: (d, _) => d.timeMS.remainder(windowSize),
                  measureFn: (d, _) {
                    final v = _selector.getValue(d);
                    if (v == null) {
                      return null;
                    } else if (v < _selector.minValue) {
                      return _selector.minValue;
                    } else if (v > _selector.maxValue) {
                      return _selector.maxValue;
                    } else {
                      return v;
                    }
                  },
                  data: _data)
            ],
                primaryMeasureAxis: charts.NumericAxisSpec(
                  viewport: charts.NumericExtents(
                      _selector.minValue, _selector.maxValue),
                  renderSpec: charts.GridlineRendererSpec<num>(
                      labelStyle: charts.TextStyleSpec(
                        color: charts.MaterialPalette.gray.shade200,
                      ),
                      lineStyle: charts.LineStyleSpec(
                        color: charts.MaterialPalette.gray.shade700,
                      )),
                ),
                domainAxis: charts.NumericAxisSpec(
                    renderSpec: charts.SmallTickRendererSpec<num>(
                        lineStyle: charts.LineStyleSpec(
                          color: charts.MaterialPalette.gray.shade50,
                        ),
                        axisLineStyle: charts.LineStyleSpec(
                          color: charts.MaterialPalette.gray.shade400,
                        )),
                    tickProviderSpec:
                        charts.StaticNumericTickProviderSpec(tickSpecs)),
                animate: false),
          ],
        ));
  }
}

abstract class RollingChartSelector<D extends TimedData> {
  String get label;
  double get minValue;
  double get maxValue;
  double getValue(D data);
}
