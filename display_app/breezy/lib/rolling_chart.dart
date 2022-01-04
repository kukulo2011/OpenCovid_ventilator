import 'dart:math';
import 'package:flutter/material.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'fitted_text.dart';
import 'data_types.dart';

/*
MIT License

Copyright (c) 2020,2021 Bill Foote

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
class TimeChart<D extends TimedData> extends StatelessWidget {
  final WindowedData<D> _data;
  final double Function(D) _selector;
  final String _label;
  final double _labelHeightFactor;
  final double _minValue;
  final double _maxValue;
  final int _numTicks;
  final charts.Color graphColor;
  final charts.Color graphOutOfRangeColor;

  /// [data] must be sorted by time.remainder(window size).
  TimeChart(
      {Key key,
      @required WindowedData<D> data,
      @required double Function(D) selector,
      @required String label,
      double labelHeightFactor = 0.14,
      @required double minValue,
      @required double maxValue,
      @required int numTicks,
      charts.Color graphColor,
      charts.Color graphOutOfRangeColor})
      : this._data = data,
        this._selector = selector,
        this._label = label,
        this._labelHeightFactor = labelHeightFactor,
        this._minValue = minValue,
        this._maxValue = maxValue,
        this._numTicks = numTicks,
        this.graphColor = (graphColor == null) ? defaultGraphColor : graphColor,
        this.graphOutOfRangeColor = (graphOutOfRangeColor == null)
            ? charts.MaterialPalette.red.shadeDefault
            : graphOutOfRangeColor,
        super(key: key);

  static charts.Color defaultGraphColor =
      charts.MaterialPalette.blue.shadeDefault.lighter;
  static charts.Color defaultGraphOutOfRangeColor =
      charts.MaterialPalette.red.shadeDefault;
  static final _labelStyle = TextStyle(color: Colors.grey[400]);

  @override
  Widget build(BuildContext context) {
    final tickSpecs = List<charts.TickSpec<double>>(_numTicks);
    for (int i = 0; i < _numTicks; i++) {
      tickSpecs[i] = charts.TickSpec(
          i.toDouble() * _data.windowSize / (_numTicks - 1),
          label: '');
    }
    final int labelSpaceFlex =
        max(1, min(30, (100 * _labelHeightFactor / 1.4).round()));
    final timeOffset = _data.timeOffset;
    final windowSize = _data.windowSize;

    return Container(
        child: Stack(
      children: <Widget>[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 8, child: SizedBox.expand()),
          Expanded(
            flex: 90,
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: FractionallySizedBox(
                  widthFactor: 1.0,
                  heightFactor: _labelHeightFactor,
                  child: FittedText(_label, style: _labelStyle)),
            ),
          ),
          Spacer()
        ]),
        Column(
          children: <Widget>[
            Expanded(flex: labelSpaceFlex, child: Container()),
            Expanded(
              flex: 100 - labelSpaceFlex,
              child: ClipRect(
                // Sleazy workaround for https://github.com/google/charts/issues/439
                child: charts.LineChart(<charts.Series<D, double>>[
                  charts.Series<D, double>(
                      id: 'data',
                      colorFn: (d, __) {
                        final v = _selector(d);
                        if (v == null) {
                          return graphColor; // doesn't matter
                        } else if (v < _minValue || v > _maxValue) {
                          return graphOutOfRangeColor;
                        } else {
                          return graphColor;
                        }
                      },
                      domainFn: (d, _) =>
                          (d.timeS - timeOffset).remainder(windowSize),
                      measureFn: (d, _) {
                        final v = _selector(d);
                        if (v == null || !v.isFinite) {
                          return null;
                        } else if (v < _minValue) {
                          return _minValue;
                        } else if (v > _maxValue) {
                          return _maxValue;
                        } else {
                          return v;
                        }
                      },
                      data: _data.window)
                ],
                    primaryMeasureAxis: charts.NumericAxisSpec(
                      viewport: charts.NumericExtents(_minValue, _maxValue),
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
              ),
            ),
          ],
        ),
      ],
    ));
  }
}
