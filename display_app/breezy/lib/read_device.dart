import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:pedantic/pedantic.dart' show unawaited;

import 'configure.dart';
import 'main.dart' show Log, Settings, BreezyGlobals;
import 'deques.dart' show TimedData;
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
  final String newScreen;

  DeviceData(double timeS, List<double> chartedValues, this.displayedValues,
      this.newScreen)
      : chart = ChartData(timeS, chartedValues) {
    assert(displayedValues != null);
    assert(newScreen != null);
  }
}

class ChartData extends TimedData {
  final List<double> values;
  @override
  final double timeS; // Time in seconds

  ChartData(this.timeS, this.values) {
    assert(timeS != null);
    assert(values != null);
  }

  ChartData.dummy(this.timeS) : values = null;
}

abstract class DeviceDataListener {
  Future<void> processDeviceData(DeviceData d);
  Future<void> processNewConfiguration(BreezyConfiguration c);
}

abstract class DeviceDataSource {
  final config.BreezyConfiguration configuration;
  final config.DataFeed feedSpec;
  DeviceDataListener _listener;

  DeviceDataSource(this.configuration) : feedSpec = configuration.feed;

  /// A device data source for debugging the screen.  It produces data values
  /// expected to take the maximum screen width, logging values that go
  /// out of range, and stuff like that.
  static DeviceDataSource screenDebug(
          config.BreezyConfiguration configuration) =>
      _ScreenDebugDeviceDataSource(configuration);

  /// A source that reads from a file that's baked into the asset bundle, or
  /// the screen configuration
  static DeviceDataSource fromSampleLog(BreezyGlobals globals, AssetBundle b) =>
      _AssetFileDataSource(globals, b);

  /// A source that takes serial data from the USB port
  static DeviceDataSource fromSerial(
          Settings settings, config.BreezyConfiguration configuration) =>
      _SerialDataSource(settings, configuration);

  /// A source that opens a server socket, and accepts connections to send
  /// us data.  Useful for debugging.
  static DeviceDataSource serverSocket(
          BreezyGlobals globals, AssetBundle bundle) =>
      _ServerSocketDataSource(globals, bundle);

  /// A source using Bluetooth Classic/rfcomm
  static DeviceDataSource bluetoothClassic(BreezyGlobals globals) =>
      _BluetoothClassicDataSource(globals.settings, globals.configuration);

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
    implements StringStreamListener {
  final int _cr = '\r'.codeUnitAt(0);
  static final int _newline = '\n'.codeUnitAt(0);
  static final int _hash = '#'.codeUnitAt(0);
  final int _resetTimeGap; // In ticks
  Settings settings;
  ByteStreamReader reader;
  BreezyConfigurationJsonReader configReader;
  final bool _meterData;
  final _lineBuffer = StringBuffer();
  int _lastTime; // Last time seen in file.  Starts out null
  int _currTime; // 64 bits, in ticks
  DateTime _startTime;

  _ByteStreamDataSource(
      this.settings, config.BreezyConfiguration configuration, this._meterData)
      : this._resetTimeGap = // About 40ms:
            max(1, (((40 / 1000) * configuration.feed.ticksPerSecond).round())),
        super(configuration) {
    _currTime = -_resetTimeGap;
  }

  @override
  void start(DeviceDataListener listener) {
    super.start(listener);
    reader = createReader(settings);
    unawaited(reader.start());
  }

  ByteStreamReader createReader(Settings settings);

  /// Reset for a new connection from a source that supports multiple
  /// connections, like a server socket.
  @mustCallSuper
  Future<void> reset() {
    return _resetTime();
  }

  Future<void> _resetTime() async {
    _lastTime = null;
  }

  @override
  void stop() {
    super.stop();
    reader.stop();
  }

  @override
  Future<void> receive(String data) async {
    for (int ch in data.codeUnits) {
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
    if (configReader != null) {
      configReader.acceptLine(line);
      if (configReader.done) {
        try {
          final newConfig = configReader.getResult();
          await _listener.processNewConfiguration(newConfig);
        } catch (ex, st) {
          await send('\r\n\nStack trace:  $st\r\n\n');
          await send('Error in new config:  $ex\r\n\n');
        } finally {
          configReader = null;
        }
      }
      return;
    } else if (line.isEmpty || line.codeUnitAt(0) == _hash) {
      await Future.delayed(Duration(microseconds: 250), () => null);
      // Just a bit of robustness if we get flooded by comments
      return;
    } else if ('read-config' == line) {
      configReader = BreezyConfigurationJsonReader(compact: false);
      return;
    } else if (line.startsWith('read-config-compact:')) {
      try {
        int checksum = int.parse(line.substring(20), radix: 16);
        // The Linux crc32 command uses hex, so I did too.
        configReader =
            BreezyConfigurationJsonReader(compact: false, checksum: checksum);
      } catch (ex) {
        await send('Error in command:  $ex\r\n');
      }
      return;
    } else if ('reset-time' == line) {
      return _resetTime();
    }

    List<String> parts = line.split(',');
    try {
      int pos = 0;
      final numParts =
          feedSpec.numFeedValues + 4 + (feedSpec.screenSwitchCommand ? 1 : 0);
      if (parts.length != numParts) {
        Log.writeln('Wrong # of commas in "$line"');
      } else if (parts[pos++] != feedSpec.protocolName) {
        Log.writeln('"${feedSpec.protocolName}" not first in "$line"');
      } else if (int.parse(parts[pos++]) != feedSpec.protocolVersion) {
        Log.writeln('version not ${feedSpec.protocolVersion} in "$line"');
      } else {
        final int time = int.parse(parts[pos++]);
        final charted = Float64List(feedSpec.chartedValues.length);
        final displayed = List<String>(feedSpec.displayedValues.length);
        for (int i = 0; i < charted.length; i++) {
          final fs = feedSpec.chartedValues[i];
          charted[i] = double.tryParse(parts[pos + fs.feedIndex]) ?? double.nan;
        }
        for (int i = 0; i < displayed.length; i++) {
          final fs = feedSpec.displayedValues[i];
          displayed[i] = fs.formatFeedValue(parts[pos + fs.feedIndex]);
        }
        pos += feedSpec.numFeedValues;
        final newScreen = (feedSpec.screenSwitchCommand) ? parts[pos++] : '';
        int checksum = int.parse(parts[pos++]);
        assert(pos == numParts);
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
          int deltaT = (time - _lastTime) % feedSpec.timeModulus;
          if (deltaT <= 0) {
            throw Exception('bad deltaT:  $deltaT <= 0');
          }
          _currTime += deltaT;
          if (_meterData) {
            int now = DateTime.now().difference(_startTime).inMilliseconds;
            int dNow =
                (_currTime * (1000 / feedSpec.ticksPerSecond)).round() - now;
            if (dNow > 0) {
              await Future.delayed(Duration(milliseconds: dNow), () => null);
            }
          }
        }
        _lastTime = time;

        final l = _listener;
        if (l != null) {
          await l.processDeviceData(DeviceData(
              _currTime / feedSpec.ticksPerSecond,
              charted,
              displayed,
              newScreen));
        }
      }
    } catch (ex) {
      Log.writeln('$ex for "$line"');
    }
  }

  /// Send an informative message to our source, if that source is
  /// capable and interested.
  Future<void> send(String message) {
    return Future.value(null);
  }
}

class _AssetFileDataSource extends _ByteStreamDataSource {
  final AssetBundle bundle;
  final BreezyConfiguration config;

  _AssetFileDataSource(BreezyGlobals globals, this.bundle)
      : this.config = globals.configuration,
        super(globals.settings, globals.configuration, true);

  @override
  ByteStreamReader createReader(Settings settings) {
    return AssetFileReader(settings, config, bundle, this);
  }
}

class _SerialDataSource extends _ByteStreamDataSource {
  _SerialDataSource(Settings settings, config.BreezyConfiguration configuration)
      : super(settings, configuration, settings.meterData);

  @override
  ByteStreamReader createReader(Settings settings) {
    return SerialReader(settings, this);
  }
}

class _ServerSocketDataSource extends _ByteStreamDataSource {
  final int portNumber;
  final String securityString;
  final BreezyConfiguration config;
  final AssetBundle bundle;
  bool firstLineMatched = false;
  ServerSocketReader socketReader;

  _ServerSocketDataSource(BreezyGlobals globals, this.bundle)
      : this.portNumber = globals.settings.socketPort,
        this.securityString = globals.settings.securityString,
        this.config = globals.configuration,
        super(globals.settings, globals.configuration,
            globals.settings.meterData);

  @override
  ByteStreamReader createReader(Settings settings) {
    socketReader = ServerSocketReader(settings, this);
    return socketReader;
  }

  @override
  Future<void> reset() {
    firstLineMatched = false;
    configReader = null;
    return super.reset();
  }

  @override
  Future<void> send(String message) => socketReader?.send(message);

  @override
  Future<void> receiveLine(String line) async {
    if (firstLineMatched) {
      if (line == 'exit') {
        await send('Goodbye.\r\n');
        socketReader.closeThisSocket();
        return;
      } else if (line == 'write-config') {
        await send('\r\n');
        await config.writeJson(socketReader.getSink(), bundle);
        await send('\r\n');
      } else if (line == 'write-config-compact') {
        await send('\r\n');
        await config.writeCompact(socketReader.getSink(), bundle);
        await send('\r\n');
      } else if (line == 'help') {
        await send('\r\n');
        await send('exit to close socket.\r\n');
        await send('reset-time when starting data on a loop.\r\n');
        await send('write-config to write current configuration.\r\n');
        await send('write-config-compact for gzipped version.\r\n');
        await send('read-config to read a new configuration in JSON.\r\n');
        await send('    Terminated by blank line.\r\n');
        await send(
            'read-config-compact:<checksum> for the compact version.\r\n');
        await send(
            '    Takes a base64-encoded gzipped JSON configuration, terminated by blank line.\r\n');
        await send(
            '    checksum is crc32 checksum of gzipped config file, in hex\r\n');
        await send('help for this message\r\n');
        await send('\r\n');
      } else {
        return super.receiveLine(line);
      }
    } else if (line == securityString) {
      await send('Security string matched.\r\n"help" for command list.\r\n');
      firstLineMatched = true;
    } else {
      await send('Bad security string.\r\n');
      await Future.delayed(Duration(seconds: 5), () => null);
    }
  }
}

typedef _ScreenDebugFunction = double Function(double time, config.Value);

class _ScreenDebugDeviceDataSource extends DeviceDataSource {
  static final _random = Random();
  double _currTime = 0;
  final chartFunctions = List<_ScreenDebugFunction>();
  final List<double> lastValue;
  final List<double> nextChange;

  // A selection of pretty-looking functions.  They're in a list so we
  // can randomly pick different ones each time we run.
  static List<_ScreenDebugFunction> functions = [
    (double time, config.Value spec) {
      final range = spec.demoMaxValue - spec.demoMinValue;
      final frobbed = time.remainder(3.7);
      return _random.nextDouble() * range / 50 +
          (frobbed < 1.5
              ? spec.demoMinValue + range / 20
              : spec.demoMaxValue - range / 20);
    },
    (double time, config.Value spec) {
      final range = spec.demoMaxValue - spec.demoMinValue;
      final frobbed = time.remainder(3.7);
      return (frobbed < 1.5 ? range * frobbed / 1.5 : 0.0) + spec.demoMinValue;
    },
    (double time, config.Value spec) {
      final range = spec.demoMaxValue - spec.demoMinValue;
      return range * (0.5 + 0.55 * sin(time)) +
          spec.demoMinValue; // Some out of range
    },
  ];

  _ScreenDebugDeviceDataSource(config.BreezyConfiguration configuration)
      : lastValue = Float64List(configuration.feed.displayedValues.length),
        nextChange = Float64List(configuration.feed.displayedValues.length),
        super(configuration) {
    final candidates = List<_ScreenDebugFunction>();
    for (final config.Value _ in feedSpec.chartedValues) {
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
              lastValue[i] = spec.demoMinValue;
            } else {
              lastValue[i] = spec.demoMaxValue;
            }
          } else {
            lastValue[i] = spec.demoMinValue +
                (spec.demoMaxValue - spec.demoMinValue) * _random.nextDouble();
          }
        }
        displayed[i] = spec.formatValue(lastValue[i]);
      }
      String newScreen = '';
      if (feedSpec.screenSwitchCommand && _random.nextDouble() < 1 / 200) {
        newScreen = configuration
            .screens[_random.nextInt(configuration.screens.length)].name;
      }
      final l = _listener;
      if (l != null) {
        await l.processDeviceData(
            DeviceData(_currTime, charted, displayed, newScreen));
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      _currTime = DateTime.now().difference(startTime).inMilliseconds / 1000.0;
    }
  }
}

class _BluetoothClassicDataSource extends _ByteStreamDataSource {
  _BluetoothClassicDataSource(
      Settings settings, config.BreezyConfiguration configuration)
      : super(settings, configuration, settings.meterData);

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
