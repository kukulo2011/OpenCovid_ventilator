import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:pedantic/pedantic.dart' show unawaited;

import 'main.dart' show Log, Settings, BreezyGlobals;
import 'dequeues.dart' show TimedData;
import 'configure.dart' as config;
import 'reader.dart';
import 'dart:async';
import 'dart:typed_data';
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

/// One data sample from the device
class DeviceData {
  final List<String> displayedValues;
  final ChartData chart;

  DeviceData(double timeMS, List<double> chartedValues, this.displayedValues)
      : chart = ChartData(timeMS, chartedValues) {
    assert(displayedValues.length == 11);
  }
}

class ChartData extends TimedData {
  final List<double> values;
  @override
  final double timeMS;

  ChartData(this.timeMS, this.values) {
    assert(timeMS != null);
    assert(values != null);
  }

  ChartData.dummy(this.timeMS) : values = null;
}

abstract class DeviceDataListener {
  Future<void> processDeviceData(DeviceData d);
}

abstract class DeviceDataSource {
  final config.DataFeed feedSpec;
  DeviceDataListener _listener;

  DeviceDataSource(this.feedSpec);

  /// A device data source for debugging the screen.  It produces data values
  /// expected to take the maximum screen width, logging values that go
  /// out of range, and stuff like that.
  static DeviceDataSource screenDebug(config.DataFeed feed) =>
      _ScreenDebugDeviceDataSource(feed);

  /// A source that reads from a file that's baked into the asset bundle
  static DeviceDataSource fromAssetFile(
          Settings settings, config.DataFeed feed, AssetBundle b) =>
      _AssetFileDataSource(settings, feed, b);

  /// A source that takes serial data from the USB port
  static DeviceDataSource fromSerial(Settings settings, config.DataFeed feed) =>
      _SerialDataSource(settings, feed);

  /// A source that opens a server socket, and accepts connections to send
  /// us data.  Useful for debugging.
  static DeviceDataSource serverSocket(BreezyGlobals globals) =>
      _ServerSocketDataSource(globals.settings, globals.deviceIPAddresses,
          globals.configuration.feed);

  /// A source using Bluetooth Classic/rfcomm
  static DeviceDataSource bluetoothClassic(BreezyGlobals globals) =>
      _BluetoothClassicDataSource(globals.settings, globals.configuration.feed);

  bool get running => _listener != null;

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

abstract class _ByteStreamDataSource extends DeviceDataSource
    implements ByteStreamListener {
  final int _cr = '\r'.codeUnitAt(0);
  static final int _newline = '\n'.codeUnitAt(0);
  static final int _hash = '#'.codeUnitAt(0);
  static const _resetTimeGap = 40;   // ms
  Settings settings;
  ByteStreamReader reader;
  final bool _meterData;
  final _lineBuffer = StringBuffer();
  int _lastTime; // Last time seen in file.  Starts out null
  int _currTime = -_resetTimeGap; // 64 bits
  DateTime _startTime;

  _ByteStreamDataSource(this.settings, config.DataFeed feed, this._meterData)
      : super(feed);

  @override
  start(DeviceDataListener listener) {
    super.start(listener);
    reader = createReader(settings);
    unawaited(reader.start());
  }

  ByteStreamReader createReader(Settings settings);

  @override
  @mustCallSuper
  /// Reset for a new connection from a source that supports multiple
  /// connections, like a server socket.
  Future<void> reset() {
    return _resetTime();
  }

  Future<void> _resetTime() async {
    _lastTime = null;
    final charted = List<double>(3);  // full of nulls
    final displayed = List<String>(11);
    for (int i = 0; i < displayed.length; i++) {
      displayed[i] = '';
    }
    /*  If we want a gap when there's a reset-time:
    final l = _listener;
    if (l != null) {
      final t = _currTime + _resetTimeGap ~/ 2;
      return l.processDeviceData(
        DeviceData(t / 1000.0, charted, displayed));
    }
     */
  }

  @override
  void stop() {
    super.stop();
    reader.stop();
  }

  @override
  Future<void> receive(Uint8List data) async {
    for (int ch in data) {
      if (ch == _cr) {
        // skip
      } else if (ch == _newline || _lineBuffer.length > 500) {
        await receiveLine(_lineBuffer.toString());
        _lineBuffer.clear();
      } else {
        _lineBuffer.writeCharCode(ch);
      }
    }
  }

  Future<void> receiveLine(String line) async {
    if (line.isEmpty || line.codeUnitAt(0) == _hash) {
      await Future.delayed(Duration(microseconds: 250), () => null);
      // Just a bit of robustness if we get flooded by comments
      return;
    } else if ('reset-time' == line) {
      return _resetTime();
    }
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
        if (checksum == -1 && feedSpec.checksumIsOptional) {
          // That's OK
        } else {
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
        if (_meterData && _startTime == null) {
          _startTime = DateTime.now();
        }
        if (_lastTime == null) {
          _currTime += _resetTimeGap;
        } else {
          int deltaT = (time - _lastTime) & 0xffff;
          if (deltaT <= 0) {
            throw Exception('bad deltaT:  $deltaT <= 0');
          }
          _currTime += deltaT;
          if (_meterData) {
            int now = DateTime.now().difference(_startTime).inMilliseconds;
            int dNow = _currTime - now;
            if (dNow > 0) {
              await Future.delayed(Duration(milliseconds: dNow), () => null);
            }
          }
        }
        _lastTime = time;

        final l = _listener;
        if (l != null) {
          await l.processDeviceData(
              DeviceData(_currTime / 1000.0, charted, displayed));
        }
      }
    } catch (ex) {
      Log.writeln('$ex for "$line"');
    }
  }
}

class _AssetFileDataSource extends _ByteStreamDataSource {
  AssetBundle bundle;

  _AssetFileDataSource(Settings settings, config.DataFeed feed, this.bundle)
      : super(settings, feed, true);

  @override
  ByteStreamReader createReader(Settings settings) {
    return AssetFileReader(settings, bundle, this);
  }
}

class _SerialDataSource extends _ByteStreamDataSource {
  _SerialDataSource(Settings settings, config.DataFeed feed)
      : super(settings, feed, settings.meterData);

  @override
  ByteStreamReader createReader(Settings settings) {
    return SerialReader(settings, this);
  }
}

class _ServerSocketDataSource extends _ByteStreamDataSource {
  List<String> localAddresses;
  final int portNumber;
  final String securityString;
  bool firstLineMatched = false;
  ServerSocketReader socketReader;

  _ServerSocketDataSource(
      Settings settings, this.localAddresses, config.DataFeed feed)
      : this.portNumber = settings.socketPort,
        this.securityString = settings.securityString,
        super(settings, feed, settings.meterData);

  @override
  ByteStreamReader createReader(Settings settings) {
    socketReader = ServerSocketReader(settings, this, localAddresses);
    return socketReader;
  }

  @override
  Future<void> reset() {
    firstLineMatched = false;
    return super.reset();
  }

  @override
  Future<void> receiveLine(String line) async {
    if (firstLineMatched) {
      if (line == 'exit') {
        await socketReader.send('Goodbye.\r\n');
        socketReader.closeThisSocket();
        return;
      } else {
        return super.receiveLine(line);
      }
    } else if (line == securityString) {
      await socketReader
          .send('Security string matched.\r\n"exit" will close socket.\r\n');
      firstLineMatched = true;
    } else {
      await socketReader.send('Bad security string.\r\n');
      await Future.delayed(Duration(seconds: 5), () => null);
    }
  }
}

typedef _ScreenDebugFunction = double Function(
    double time, config.ChartedValue);

class _ScreenDebugDeviceDataSource extends DeviceDataSource {
  static final _random = Random();
  double _currTime = 0;
  final chartFunctions = List<_ScreenDebugFunction>();
  final List<double> lastValue;
  final List<double> nextChange;

  // A selection of pretty-looking functions.  They're in a list so we
  // can randomly pick different ones each time we run.
  static List<_ScreenDebugFunction> functions = [
    (double time, config.ChartedValue spec) {
      final range = spec.maxValue - spec.minValue;
      final frobbed = time.remainder(3.7);
      return _random.nextDouble() * range / 50 +
          (frobbed < 1.5
              ? spec.minValue + range / 20
              : spec.maxValue - range / 20);
    },
    (double time, config.ChartedValue spec) {
      final range = spec.maxValue - spec.minValue;
      final frobbed = time.remainder(3.7);
      return (frobbed < 1.5 ? range * frobbed / 1.5 : 0.0) + spec.minValue;
    },
    (double time, config.ChartedValue spec) {
      final range = spec.maxValue - spec.minValue;
      return range * (0.5 + 0.55 * sin(time)) +
          spec.minValue; // Some out of range
    },
  ];

  _ScreenDebugDeviceDataSource(config.DataFeed feed)
      : lastValue = Float64List(feed.displayedValues.length),
        nextChange = Float64List(feed.displayedValues.length),
        super(feed) {
    final candidates = List<_ScreenDebugFunction>();
    for (final config.ChartedValue _ in feedSpec.chartedValues) {
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
    unawaited(_sendEvents());
    // _timer = Timer.periodic(Duration(milliseconds: 20), (_) => _tick());
  }

  @override
  void stop() {
    super.stop();
  }

  Future<void> _sendEvents() async {
    final startTime = DateTime.now();
    while (running) {
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
        displayed[i] = spec.formatValue(lastValue[i]);
      }
      final l = _listener;
      if (l != null) {
        await l.processDeviceData(DeviceData(_currTime, charted, displayed));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      _currTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    }
  }
}

class _BluetoothClassicDataSource extends _ByteStreamDataSource {
  _BluetoothClassicDataSource(Settings settings, config.DataFeed feed)
      : super(settings, feed, settings.meterData);

  @override
  ByteStreamReader createReader(Settings settings) {
    return BluetoothClassicReader(settings, this);
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
