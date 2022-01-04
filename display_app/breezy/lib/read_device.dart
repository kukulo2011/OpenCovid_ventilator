import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show AssetBundle;

import 'configure.dart';
import 'configure_a.dart';
import 'log.dart';
import 'main.dart' show Log, Settings, BreezyGlobals;
import 'data_types.dart';
import 'configure.dart' as config;
import 'reader.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

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

abstract class DeviceDataListener {
  Future<void> processDeviceData(DeviceData d);
  Future<void> processNewConfiguration(
      AndroidBreezyConfiguration c, DeviceDataSource Function() nextSource);
  Future<void> processError(Exception ex);
  Future<void> processEOF();
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
  static DeviceDataSource fromSampleLog(BreezyGlobals globals) =>
      _SampleLogDataSource(globals);

  /// A source that takes serial data from the USB port
  static DeviceDataSource fromSerial(
          Settings settings, config.BreezyConfiguration configuration) =>
      _SerialDataSource(settings, configuration);

  /// A source from an http/https connection.  The source can send a
  /// "next-uri:" command to us, to specify the next URI to open.
  /// It's relative to the previous URI.
  static DeviceDataSource http(
          Settings settings, config.BreezyConfiguration configuration) =>
      _HttpDataSource(settings, configuration);

  /// A source that opens a server socket, and accepts connections to send
  /// us data.  Useful for debugging.
  static DeviceDataSource serverSocket(
          BreezyGlobals globals, AssetBundle bundle) =>
      _ServerSocketDataSource(globals);

  /// A source using Bluetooth Classic/rfcomm
  static DeviceDataSource bluetoothClassic(BreezyGlobals globals) =>
      _BluetoothClassicDataSource(globals.settings, globals.configuration);

  bool get running => _listener != null;

  /// Start the data source.
  /// Start reading from our data source.  Returns a future that may
  /// complete immediately, or sometime later.  This allows the data source
  /// to detect errors, and throw exceptions as appropriate.
  @mustCallSuper
  Future<void> start(DeviceDataListener listener) async {
    assert(listener != null);
    _listener = listener;
  }

  @mustCallSuper
  void stop() {
    _listener = null;
  }

  Future<void> receiveError(Exception ex) => _listener.processError(ex);
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
  bool _meterData;
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
  Future<void> start(DeviceDataListener listener) async {
    await super.start(listener);
    reader = createReader(settings);
    await reader.start();
  }

  ByteStreamReader createReader(Settings settings);

  /// Reset for a new connection from a source that supports multiple
  /// connections, like a server socket.
  @mustCallSuper
  Future<void> reset() {
    _lineBuffer.clear();
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
    if (!running) {
      return;
    }
    for (int ch in data.codeUnits) {
      if (ch == _cr) {
        // skip
      } else if (ch == _newline || _lineBuffer.length > 500) {
        await receiveLine(_lineBuffer.toString());
        _lineBuffer.clear();
        if (!running) {
          return;
        }
      } else {
        _lineBuffer.writeCharCode(ch);
      }
    }
  }

  /// On a config change, we have the option of creating a new data source
  /// so we can chain the next screen to this input.
  DeviceDataSource _makeNextDataSource(config.BreezyConfiguration newConfig) =>
      null;

  Future<void> receiveLine(String line) async {
    if (Log.detailed) {
      Log.writeln('$this read "$line"');
    }
    if (configReader != null) {
      if (Log.detailed) {
        Log.writeln('  Sending line to config reader.');
      }
      configReader.acceptLine(line);
      if (configReader.done) {
        await _configReaderDone();
      }
      return;
    } else if (line.isEmpty || line.codeUnitAt(0) == _hash) {
      await Future.delayed(Duration(microseconds: 250), () => null);
      // Just a bit of robustness if we get flooded by comments
      return;
    } else if (line.startsWith('meter-data:')) {
      _meterData = line.substring(11).trim().toLowerCase() != 'off';
      Log.writeln('meterData set to $_meterData from feed.');
      return;
    } else if ('read-config' == line) {
      Log.writeln('Reading a new configuration...');
      configReader = makeNewConfigReader();
      return;
    } else if (line.startsWith('read-config-compact:')) {
      Log.writeln('Reading a new compact configuration...');
      try {
        int checksum = int.parse(line.substring(20), radix: 16);
        // The Linux crc32 command uses hex, so I did too.
        configReader = makeNewConfigReader(compact: false, checksum: checksum);
      } catch (ex) {
        await send('Error in command:  $ex\r\n');
      }
      return;
    } else if ('reset-time' == line) {
      Log.writeln('Resetting time...');
      return _resetTime();
    }

    List<String> parts = line.split(',');
    try {
      int pos = 0;
      final numParts =
          feedSpec.numFeedValues + 4 + (feedSpec.screenSwitchCommand ? 1 : 0);
      if (parts.length != numParts) {
        Log.writeln(
            'Expected $numParts parts but got ${parts.length} in "$line"');
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
            return;
          }
        }
        assert(pos == parts.length);
        if (_meterData && _startTime == null) {
          _startTime = DateTime.now();
        }
        if (_lastTime == null) {
          _currTime += _resetTimeGap;
        } else {
          int deltaT = time - _lastTime;
          if (feedSpec.timeModulus != null) {
            deltaT %=
                feedSpec.timeModulus; // In Dart (unlike C), guaranteed positive
          }
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

  BreezyConfigurationJsonReader makeNewConfigReader(
          {bool compact = false, int checksum}) =>
      BreezyConfigurationJsonReader(compact: compact, checksum: checksum);

  Future<void> _configReaderDone() async {
    try {
      Log.writeln('Finished reading new configuration');
      final newConfig = configReader.getResult();
      await _listener.processNewConfiguration(
          newConfig, () => _makeNextDataSource(newConfig));
      Log.writeln('New configuration processed');
    } catch (ex, st) {
      await send('\r\n\nStack trace:  $st\r\n\n');
      await send('Error in new config:  $ex\r\n\n');
      Log.writeln();
      Log.writeln('$st');
      Log.writeln();
      Log.writeln('Error in new config:  $ex');
      Log.writeln();
    } finally {
      configReader = null;
    }
  }

  /// Send an informative message to our source, if that source is
  /// capable and interested.
  Future<void> send(String message) {
    return Future.value(null);
  }
}

class _SampleLogDataSource extends _ByteStreamDataSource {
  final BreezyConfiguration config;

  _SampleLogDataSource(BreezyGlobals globals)
      : this.config = globals.configuration,
        super(globals.settings, globals.configuration, true);

  @override
  ByteStreamReader createReader(Settings settings) {
    return AssetFileReader(settings, config, this);
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

class _HttpDataSource extends _ByteStreamDataSource {
  HttpClient client;
  Uri nextUri;
  Uri lastUri;

  _HttpDataSource(Settings settings, config.BreezyConfiguration configuration)
      : super(settings, configuration, settings.meterData) {
    nextUri = Uri.parse(settings.httpUrl);
  }

  @override
  DeviceDataSource _makeNextDataSource(config.BreezyConfiguration newConfig) {
    if (nextUri == null) {
      return null;
    }
    final result = _HttpDataSource(settings, newConfig);
    result.nextUri = nextUri;
    nextUri = null;
    return result;
  }

  @override
  ByteStreamReader createReader(Settings settings) {
    lastUri = nextUri;
    nextUri = null;
    return HttpReader(client, lastUri, settings, this);
  }

  @override
  Future<void> start(DeviceDataListener listener) async {
    client = HttpClient();
    await super.start(listener);
  }

  @override
  Future<void> receiveLine(String line) {
    if (line.startsWith('next-url:')) {
      try {
        final maybeRelative = Uri.parse(line.substring(9).trim());
        nextUri = lastUri.resolveUri(maybeRelative);
      } catch (ex) {
        Log.writeln('Invalid Uri from http connection:  $line');
      }
      return Future<void>.value(null);
    } else {
      return super.receiveLine(line);
    }
  }

  @override
  void stop() {
    super.stop();
    client?.close();
  }

  @override
  Future<void> reset() async {
    await super.reset();
    if (running) {
      if (configReader != null) {
        configReader.acceptEOF();
        assert(configReader.done);
        await _configReaderDone();
      }
      if (nextUri == null) {
        unawaited(_listener.processEOF());
      } else {
        reader = createReader(settings);
        try {
          await reader.start();
        } catch (ex, st) {
          if (st == null) {
            Log.writeln(ex);
          } else {
            Log.writeln(st);
          }
          nextUri = null;
          if (ex is Exception) {
            await _listener.processError(ex);
          } else {
            await _listener.processError(Exception(ex.toString));
          }
          unawaited(_listener.processEOF());
        }
      }
    }
  }
}

class _ServerSocketDataSource extends _ByteStreamDataSource {
  final int portNumber;
  final String securityString;
  final BreezyConfiguration config;
  bool debugMode = false;
  bool firstLineMatched = false;
  ServerSocketReader socketReader;

  _ServerSocketDataSource(BreezyGlobals globals)
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
    debugMode = false;
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
        await config.writeJson(socketReader.getSink());
        await send('\r\n');
      } else if (line == 'write-config-compact') {
        await send('\r\n');
        await config.writeCompact(socketReader.getSink());
        await send('\r\n');
      } else if (line == 'debug') {
        debugMode = true;
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
        await send(
            'debug to turn on debug for this connection.  Gives better JSON syntax errors.\r\n');
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

  @override
  BreezyConfigurationJsonReader makeNewConfigReader(
      {bool compact = false, int checksum}) {
    final DebugSink out = debugMode ? socketReader : null;
    return BreezyConfigurationJsonReader(
        compact: compact, checksum: checksum, debug: out);
  }

  @override
  Future<void> _configReaderDone() async {
    await super._configReaderDone();
    if (debugMode) {
      await send(null); // Essentially, flush(), for any debug output.
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
      if (range <= 0) {
        return spec.demoMinValue;
      }
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
  Future<void> start(DeviceDataListener listener) async {
    await super.start(listener);
    unawaited(_sendEvents());
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
