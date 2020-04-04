import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:pedantic/pedantic.dart' show unawaited;
import 'package:usb_serial/usb_serial.dart';

import 'main.dart' show Log, Settings;
import 'rolling_deque.dart' show TimedData;
import 'spec.dart' as spec;
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

class DataFeed {
  final int numberOfParts = 18;
}

abstract class DeviceDataListener {
  void processDeviceData(DeviceData d);
}

abstract class DeviceDataSource {
  final spec.DataFeed feedSpec;
  DeviceDataListener _listener;

  DeviceDataSource(this.feedSpec);

  /// A device data source for debugging the screen.  It produces data values
  /// expected to take the maximum screen width, logging values that go
  /// out of range, and stuff like that.
  static DeviceDataSource screenDebug(Settings settings) =>
      _ScreenDebugDeviceDataSource(settings);

  /// A source that reads from a file that's baked into the asset bundle
  static DeviceDataSource fromAssetFile(AssetBundle b, String name) =>
      _AssetFileDataSource(b, name);

  static DeviceDataSource fromSerial(Settings settings) =>
      _SerialDataSource(settings);

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
  final bool _meterData;
  final _lineBuffer = StringBuffer();
  int _lastTime; // Starts out null
  int _currTime = 0; // 64 bits
  bool _stopped = false;
  DateTime _startTime;

  _ByteStreamDataSource(spec.DataFeed feed, this._meterData) : super(feed);

  @override
  start(DeviceDataListener listener) {
    super.start(listener);
    if (_meterData) {
      _startTime = DateTime.now();
    }
    _stopped = false;
    unawaited(readUntilStopped());
  }

  Future<void> readUntilStopped();

  @override
  void stop() {
    super.stop();
    _stopped = true;
    _startTime = null;
  }

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
        if (checksum != -1) {
          final crc = Crc16();
          final lastComma = line.lastIndexOf(",");
          for (int i = 0; i <= lastComma; i++) {
            crc.addByte(line.codeUnitAt(i));
          }
          if (checksum != crc.result) {
            Log.writeln(
                'crc16 calculated:  ${crc.result} received:  $checksum');
          }
        }
        assert(pos == parts.length);
        if (_lastTime != null) {
          int deltaT = (time - _lastTime) & 0xffff;
          if (deltaT <= 0) {
            throw Exception('bad deltaT:  $deltaT <= 0');
          }
          _currTime += deltaT;
          if (_meterData) {
            int now = DateTime.now().difference(_startTime).inMilliseconds;
            int dNow = _currTime - now;
            if (dNow > 0) {
              waited = true;
              await Future.delayed(Duration(milliseconds: dNow), () => null);
            }
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

  _AssetFileDataSource(this._bundle, this._name)
      : super(spec.DataFeed.defaultFeed, true);

  @override
  Future<void> readUntilStopped() async {
    while (!_stopped) {
      ByteData d = await _bundle.load(_name);
      await receive(d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes));
      // Just keep time marching forward, while looping through the data.
      _lastTime = null;
    }
  }
}

class _SerialDataSource extends _ByteStreamDataSource {
  final int baudRate;
  final int portNumber;
  UsbPort _port;

  _SerialDataSource(Settings settings)
      : this.baudRate = settings.baudRate,
        this.portNumber = settings.serialPortNumber,
        super(settings.dataFeedSpec, settings.meterData);

  @override
  void stop() {
    super.stop();
    if (_port != null) {
      try {
        _port.close();
        _port = null;
      } catch (ex) {
        Log.writeln("Error closing serial port:  $ex");
      }
    }
  }

  @override
  Future<void> readUntilStopped() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    try {
      if (_stopped) {
        return;
      }
      _port = await devices[portNumber - 1].create();
      if (_stopped) {
        return;
      }
      if (!(await _port.open())) {
        throw Exception("Failed to open device.");
      }
      if (_stopped) {
        return;
      }
      await _port.setDTR(true);
      if (_stopped) {
        return;
      }
      await _port.setRTS(true);
      if (_stopped) {
        return;
      }
      await _port.setPortParameters(baudRate, UsbPort.DATABITS_8,
          UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
      if (_stopped) {
        return;
      }
      _port.inputStream.listen((Uint8List event) async {
        if (_stopped) {
          return;
        }
        await receive(event);
      });
    } catch (ex) {
      Log.writeln('Serial error: $ex');
    }
  }
}

typedef _ScreenDebugFunction = double Function(double time, spec.ChartedValue);

class _ScreenDebugDeviceDataSource extends DeviceDataSource {
  Timer _timer;
  static final _random = Random();
  double _currTime = 0;
  final chartFunctions = List<_ScreenDebugFunction>();
  final List<double> lastValue;
  final List<double> nextChange;

  // A selection of pretty-looking functions.  They're in a list so we
  // can randomly pick different ones each time we run.
  static List<_ScreenDebugFunction> functions = [
    (double time, spec.ChartedValue spec) {
      final range = spec.maxValue - spec.minValue;
      final frobbed = time.remainder(3.7);
      return _random.nextDouble() * range / 50 +
          (frobbed < 1.5
              ? spec.minValue + range / 20
              : spec.maxValue - range / 20);
    },
    (double time, spec.ChartedValue spec) {
      final range = spec.maxValue - spec.minValue;
      final frobbed = time.remainder(3.7);
      return (frobbed < 1.5 ? range * frobbed / 1.5  : 0.0) + spec.minValue;
    },
    (double time, spec.ChartedValue spec) {
      final range = spec.maxValue - spec.minValue;
      return range * (0.5 + 0.55 * sin(time)) + spec.minValue; // Some out of range
    },
  ];

  _ScreenDebugDeviceDataSource(Settings settings)
      : lastValue = Float64List(settings.dataFeedSpec.displayedValues.length),
        nextChange = Float64List(settings.dataFeedSpec.displayedValues.length),
        super(settings.dataFeedSpec) {
    final candidates = List<_ScreenDebugFunction>();
    for (final spec.ChartedValue _ in feedSpec.chartedValues) {
      if (candidates.isEmpty) {
        candidates.addAll(functions);
      }
      final i = _random.nextInt(candidates.length);
      chartFunctions.add(candidates[i]);
      candidates.removeAt(i);
    }
  }

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
    final charted = Float64List(feedSpec.chartedValues.length);
    for (int i = 0; i < charted.length; i++) {
      charted[i] = chartFunctions[i](_currTime, feedSpec.chartedValues[i]);
    }
    final displayed = List<String>(feedSpec.displayedValues.length);
    for (int i = 0; i < displayed.length; i++) {
      final spec = feedSpec.displayedValues[i];
      if (_currTime >= nextChange[i]) {
        nextChange[i] = _currTime + _random.nextDouble() * 4;
        if (_random.nextDouble() < 0.2) {
          // Go to min or max value 20% of the time
          if (_random.nextDouble() < 0.5) {
            lastValue[i] = spec.minValue;
          } else {
            lastValue[i] = spec.maxValue;
          }
        } else {
          lastValue[i] = spec.minValue +
              (spec.maxValue - spec.minValue) * _random.nextDouble();
        }
      }
      displayed[i] = spec.format.format(lastValue[i]);
    }
    _listener?.processDeviceData(DeviceData(_currTime, charted, displayed));
    _currTime += 0.020;
  }
}

/// Calculate a CRC-16 checksum according to CRC-16-CCITT
/// cf. https://en.wikipedia.org/wiki/Cyclic_redundancy_check
/// Translated from the C code at http://srecord.sourceforge.net/crc16-ccitt.html#source
///
/// Usage:  ```
///     int expected = ...;
///     var checksum = Crc16();
///     checksum.addByte(...)
///     checksum.addByte(...)
///     checksum.addByte(...)
///        ...
///     if (checksum.result != expected) {
///         ...
///     }
///  ```
class Crc16 {
  static const int _poly = 0x1021; // crc-ccitt mask
  int _crc = 0xffff;

  void reset() {
    _crc = 0xffff;
  }

  void addByte(int ch) {
    int v = 0x80;
    for (int i = 0; i < 8; i++) {
      final bool xor = _crc & 0x8000 != 0;
      _crc <<= 1;
      _crc &= 0xffff;
      if (ch & v != 0) {
        // Append next bit of message to end of CRC if it is not zero.
        // The zero bit placed there by the shift above need not be
        // changed if the next bit of the message is zero.
        _crc++;
        _crc &= 0xffff;
      }
      if (xor) {
        _crc = _crc ^ _poly;
      }
      // Align test bit with next bit of message byte
      v >>= 1;
    }
  }

  // Called augument_message_for_good_crc() in
  // http://srecord.sourceforge.net/crc16-ccitt.html#source
  /// Get the result.  It's OK to call this multiple times, even if
  /// data is added in between.
  int get result {
    int result = _crc;
    for (int i = 0; i < 16; i++) {
      bool xor = result & 0x8000 != 0;
      result <<= 1;
      result &= 0xffff;
      if (xor) {
        result = result ^ _poly;
      }
    }
    return result;
  }
}
