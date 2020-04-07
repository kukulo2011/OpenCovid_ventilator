import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:pedantic/pedantic.dart' show unawaited;
import 'package:usb_serial/usb_serial.dart';

import 'main.dart' show Log, Settings;
import 'dequeues.dart' show TimedData;
import 'configure.dart' as config;
import 'dart:io';
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
class DeviceData {
  final List<String> displayedValues;
  final ChartData chart;

  DeviceData(double timeMS, Float64List chartedValues, this.displayedValues)
      : chart = ChartData(timeMS, chartedValues) {
    assert(displayedValues.length == 11);
  }
}

class ChartData extends TimedData {
  final Float64List values;
  @override
  final double timeMS;

  ChartData(this.timeMS, this.values) {
    assert(timeMS != null);
    assert(values != null);
  }

  ChartData.dummy(this.timeMS) : values = null;
}

abstract class DeviceDataListener {
  void processDeviceData(DeviceData d);
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
          config.DataFeed feed, AssetBundle b, String name) =>
      _AssetFileDataSource(feed, b, name);

  static DeviceDataSource fromSerial(Settings settings, config.DataFeed feed) =>
      _SerialDataSource(settings, feed);

  static DeviceDataSource serverSocket(
          Settings settings, config.DataFeed feed) =>
      _ServerSocketDataSource(settings, feed);

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

  _ByteStreamDataSource(config.DataFeed feed, this._meterData) : super(feed);

  @override
  start(DeviceDataListener listener) {
    super.start(listener);
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
    int unwaited = 0;
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
        if (_meterData && _startTime == null) {
          _startTime = DateTime.now();
        }
        if (_lastTime != null) {
          int deltaT = (time - _lastTime) & 0xffff;
          if (deltaT <= 0) {
            throw Exception('bad deltaT:  $deltaT <= 0');
          }
          _currTime += deltaT;
          unwaited++;
          if (_meterData) {
            int now = DateTime.now().difference(_startTime).inMilliseconds;
            int dNow = _currTime - now;
            if (dNow > 0) {
              unwaited--;
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
    if (unwaited > 10) {
      // If we're on a slow device, we want to catch up as much as possible
      // before updating the screen.  Lacking anything like thread prioriries,
      // this can't be done reliably, but we can at least try to process 10
      // samples at a time if we're really behind.
      unwaited = 0;
      await Future.delayed(Duration(microseconds: 250), () => null);
    }
  }
}

class _AssetFileDataSource extends _ByteStreamDataSource {
  final AssetBundle _bundle;
  final String _name;
  bool _stopped = false;

  _AssetFileDataSource(config.DataFeed feed, this._bundle, this._name)
      : super(feed, true);

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

  _SerialDataSource(Settings settings, config.DataFeed feed)
      : this.baudRate = settings.baudRate,
        this.portNumber = settings.serialPortNumber,
        super(feed, settings.meterData);

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

class _ServerSocketDataSource extends _ByteStreamDataSource {
  final int portNumber;
  final String securityString;
  ServerSocket serverSocket;
  Socket readingFrom;
  bool firstLineMatched = false;

  _ServerSocketDataSource(Settings settings, config.DataFeed feed)
      : this.portNumber = settings.socketPort,
        this.securityString = settings.securityString,
        super(feed, settings.meterData);

  @override
  void stop() {
    super.stop();
    if (serverSocket != null) {
      unawaited(serverSocket.close());
      serverSocket = null;
    }
    if (readingFrom != null) {
      unawaited(readingFrom.close());
      readingFrom = null;
    }
  }

  @override
  Future<void> readUntilStopped() async {
    if (_stopped) {
      return;
    }
    serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, portNumber);
    // That allows IPv6 too.
    // https://api.flutter.dev/flutter/dart-io/ServerSocket/bind.html
    if (_stopped) {
      if (serverSocket != null) {
        unawaited(serverSocket.close());
        serverSocket = null;
      }
      return;
    }
    serverSocket.listen((Socket socket) {
      if (readingFrom != null) {
        socket.add('Already reading data from ${readingFrom.address}\r\n'.codeUnits);
        unawaited(socket.close());
      } else {
        if (_stopped) {
          socket.close();
        } else {
          readingFrom = socket;
          _lastTime = null;
          socket.listen((Uint8List data) async {
            await receive(data);
          }, onDone: () {
            readingFrom = null;
            firstLineMatched = false;
          });
        }
      };
    });
  }

  @override
  Future<void> receiveLine(String line) async {
    if (firstLineMatched) {
      if (line == 'exit') {
        readingFrom?.add("Goodbye.\n".codeUnits);
        await(readingFrom?.flush());
        unawaited(readingFrom.close());
        return;
      } else {
        return super.receiveLine(line);
      }
    }
    if (line == securityString) {
      readingFrom?.add('Security string matched.\n'.codeUnits);
      readingFrom?.add('"exit" will close socket.\n'.codeUnits);
      await(readingFrom?.flush());
      firstLineMatched = true;
    } else {
      readingFrom?.add('Bad security string.\n'.codeUnits);
      await(readingFrom?.flush());
      unawaited(readingFrom?.close());
    }
  }
}

typedef _ScreenDebugFunction = double Function(
    double time, config.ChartedValue);

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
