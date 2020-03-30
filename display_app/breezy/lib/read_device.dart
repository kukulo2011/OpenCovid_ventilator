import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:pedantic/pedantic.dart' show unawaited;

import 'main.dart' show Log;
import 'rolling_deque.dart' show TimedData;
import 'dart:typed_data';
import 'dart:async' show Timer;
import 'dart:math';

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

// Code to read device data goes here

/// Data from the device
class DeviceData extends TimedData {
  @override
  final double timeMS;
  final Float64List chartedValues;
  final List<String> displayedValues;

  DeviceData(this.timeMS, this.chartedValues, this.displayedValues) {
    assert(timeMS != null);
    assert(chartedValues.length == 3);
    assert(displayedValues.length == 11);
  }

  DeviceData.dummy(this.timeMS)
      : chartedValues = null,
        displayedValues = null;
}

abstract class DeviceDataListener {
  void processDeviceData(DeviceData d);
}

abstract class DeviceDataSource {
  DeviceDataListener _listener;

  /// A device data source for debugging the screen.  It produces data values
  /// expected to take the maximum screen width, logging values that go
  /// out of range, and stuff like that.
  static DeviceDataSource screenDebug() => _ScreenDebugDeviceDataSource();

  /// A source that reads from a file that's baked into the asset bundle
  static DeviceDataSource fromAssetFile(AssetBundle b, String name) =>
      _AssetFileDataSource(b, name);

  @mustCallSuper
  void start(DeviceDataListener listener) {
    assert(listener != null);
    _listener = listener;
  }

  @mustCallSuper
  void stop() {
    _listener = null;
  }
}

abstract class _ByteStreamDataSource extends DeviceDataSource {
  static final int _cr = '\r'.codeUnitAt(0);
  static final int _newline = '\n'.codeUnitAt(0);
  static final int _hash = '#'.codeUnitAt(0);
  final bool _meterReading;
  final _lineBuffer = StringBuffer();
  int _lastTime; // Starts out null
  int _currTime = 0; // 64 bits

  _ByteStreamDataSource(this._meterReading);

  Future<void> receive(Uint8List data) async {
    for (int ch in data) {
      if (ch == _cr) {
        // skip
      } else if (ch == _newline || _lineBuffer.length > 200) {
        await receiveLine(_lineBuffer.toString());
        _lineBuffer.clear();
      } else {
        _lineBuffer.writeCharCode(ch);
      }
    }
  }

  Future<void> receiveLine(String line) async {
    if (line.isEmpty || line.codeUnitAt(0) == _hash) {
      // See the end of this method
      await Future.delayed(Duration(microseconds: 250), () => null);
      return;
    }
    bool waited = false;
    List<String> parts = line.split(',');
    try {
      if (parts.length != 18) {
        Log.writeln('Wrong # of commas in "$line"');
      } else if (parts[0] != 'breezy') {
        Log.writeln('"breezy" not first in "$line"');
      } else if (int.parse(parts[1]) != 1) {
        Log.writeln('version not 1 in "$line"');
      } else {
        int pos = 2;
        final int time = int.parse(parts[pos++]);
        final charted = Float64List(3);
        final displayed = List<String>(11);
        for (int i = 0; i < charted.length; i++) {
          charted[i] = double.parse(parts[pos++]);
        }
        for (int i = 0; i < displayed.length; i++) {
          displayed[i] = parts[pos++];
        }
        int checksum = int.parse(parts[pos++]);
        // TODO:  Check checksum
        assert(pos == parts.length);
        if (_lastTime != null) {
          int deltaT = (time - _lastTime) & 0xffff;
          if (deltaT <= 0) {
            throw Exception('bad deltaT:  $deltaT <= 0');
          }
          _currTime += deltaT;
          if (_meterReading) {
            waited = true;
            await Future.delayed(Duration(milliseconds: deltaT), () => null);
          }
        }
        _lastTime = time;

        _listener?.processDeviceData(
            DeviceData(_currTime / 1000.0, charted, displayed));
      }
    } catch (ex) {
      Log.writeln('$ex for "$line"');
    }
    // We put a slight delay in, so that if a device floods us with data,
    // the application stands a chance of remaining responsive.  In normal
    // operation, a line of about 100 characters comes every 20ms, so this
    // slight delay will have no effect.
    if (!waited) {
      await Future.delayed(Duration(microseconds: 250), () => null);
    }
  }
}

class _AssetFileDataSource extends _ByteStreamDataSource {
  final AssetBundle _bundle;
  final String _name;
  bool _stopped = false;

  _AssetFileDataSource(this._bundle, this._name) : super(true);

  @override
  start(DeviceDataListener listener) {
    super.start(listener);
    _stopped = false;
    unawaited(readUntilStopped());
  }

  Future<void> readUntilStopped() async {
    while (!_stopped) {
      ByteData d = await _bundle.load(_name);
      await receive(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
      // Just keep time marching forward, while looping through the data.
      _lastTime = null;
    }
  }
}

class _ScreenDebugDeviceDataSource extends DeviceDataSource {
  Timer _timer;
  static final _random = Random();
  double _currTime = 0;

  _ScreenDebugDeviceDataSource();

  @override
  void start(DeviceDataListener listener) {
    super.start(listener);
    assert(_timer == null);
    _timer = Timer.periodic(Duration(milliseconds: 20), (_) => _tick());
  }

  @override
  void stop() {
    super.stop();
    _timer.cancel();
    _timer = null;
  }

  void _tick() {
    final charted = Float64List(3);
    final frobbed = _currTime.remainder(3.7);
    charted[0] = _random.nextDouble() * 5 + (frobbed < 1.5 ? -80 : 90);
    charted[1] = (frobbed < 1.5 ? frobbed * 50 : -99);
    charted[2] = 500.0 + 550 * sin(_currTime); // Some out of range
    final displayed = List<String>(11);
    displayed[0] = "MM.M"; // 'M' is usually the widest character
    displayed[1] = "MM.M";
    displayed[2] = "MM.M";
    displayed[3] = "MM.M";
    displayed[4] = "1MM";
    displayed[5] = "MM.M";
    displayed[6] = "MM.M";
    displayed[7] = "MM.M";
    displayed[8] = "MM.M";
    displayed[9] = "MMMM";
    displayed[10] = "MMMM";
    _listener?.processDeviceData(DeviceData(_currTime, charted, displayed));
    _currTime += 0.020;
  }
}
