import 'package:flutter/foundation.dart';
import 'package:pedantic/pedantic.dart' show unawaited;
import 'package:usb_serial/usb_serial.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    show BluetoothConnection, FlutterBluetoothSerial;

import 'configure.dart';
import 'main.dart' show Log, Settings, BreezyGlobals;
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';
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

/// Interface for customers of a ByteStreamReader.
abstract class StringStreamListener {
  /// Receive data from the stream.
  Future<void> receive(String input);

  // Reset the listener because the stream ended.  The reader should prepare
  // for a (potential) new stream.
  Future<void> reset();
}

abstract class ByteStreamReader {
  final Settings settings;
  final StringStreamListener listener;
  bool stopped = false;
  final _events = Queue<String>();
  int _bytesInBuffer = 0;
  final int _bufferSize = 512;
  // https://github.com/kukulo2011/OpenCovid_ventilator/issues/18
  bool _processingQueue = false;
  StreamSubscription<String> _subscription;
  Completer<void> _subscriptionDone;
  void Function() _subscriptionOnDone;
  Completer<void> _resetPending;

  ByteStreamReader(this.settings, this.listener);

  /// Start reading from our data source
  Future<void> start();

  /// Shut down the reader
  @mustCallSuper
  void stop() {
    stopped = true;
    _finishSubscription();
  }

  @mustCallSuper
  void _finishSubscription() {
    if (_subscription != null) {
      unawaited(_subscription.cancel());
      _subscription = null;
    }
    final sd = _subscriptionDone;
    final sod = _subscriptionOnDone;
    _subscriptionDone = null;
    _subscriptionOnDone = null;
    sd?.complete(null);
    if (sod != null) {
      sod();
    }
  }

  Future<void> _readStream(Stream<List<int>> stream, {void Function() onDone}) {
    _subscriptionDone = Completer<void>();
    _subscriptionOnDone = onDone;
    final done = _subscriptionDone.future;
    if (stopped) {
      _finishSubscription();
      return done;
    }
    _subscription = Utf8Decoder().bind(stream).listen((String data) {
      _receive(data);
    }, onDone: () {
      _finishSubscription();
    });
    return done;
  }

  void _receive(String event) {
    _bytesInBuffer += event.length;
    _events.add(event);
    _pauseIfNeeded();
    if (!_processingQueue) {
      unawaited(_processQueue());
    }
  }

  Future<void> _processQueue() async {
    _processingQueue = true;
    try {
      while (_events.isNotEmpty) {
        final event = _events.removeFirst();
        final eventLen = event.length;
        const maxChunk = 2000;
        if (eventLen <= maxChunk) {
          if (stopped) {
            return;
          }
          await listener.receive(event);
          _bytesInBuffer -= eventLen;
          _resumeIfReady();
        } else {
          // This should only happens in a stress test, where the device is
          // being flooded by data.  In that case, sockets, for example,
          // have a pretty big buffer.
          for (int i = 0; i < eventLen; i += maxChunk) {
            if (stopped) {
              return;
            }
            final len = min(eventLen - i, maxChunk);
            await listener.receive(event.substring(i, i + len));
            _bytesInBuffer -= len;
            _resumeIfReady();
          }
        }
      }
    } finally {
      _processingQueue = false;
      _resetPending?.complete(null);
    }
  }

  void _resumeIfReady() {
    if (_bytesInBuffer < _bufferSize && _subscription?.isPaused == true) {
      _subscription.resume();
    }
  }

  void _pauseIfNeeded() {
    if (_bytesInBuffer >= _bufferSize && _subscription?.isPaused == false) {
      _subscription.pause();
    }
  }

  @mustCallSuper
  Future<void> _reset() async {
    if (_processingQueue) {
      _resetPending = Completer<void>();
      await _resetPending.future;
      _resetPending = null;
    }
    await listener.reset();
  }
}

class SerialReader extends ByteStreamReader {
  UsbPort _port;

  SerialReader(Settings settings, StringStreamListener listener)
      : super(settings, listener);

  @override
  Future<void> start() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    Log.writeln('${devices.length} USB devices seen');
    for (var d in devices) {
      Log.writeln('  $d');
    }
    if (devices.isEmpty) {
      return;
    }
    int deviceNum = settings.serialPortNumber;
    Log.writeln('Device $deviceNum was chosen in settings.');
    if (deviceNum == null) {
      return;
    }
    deviceNum--;
    if (deviceNum < 0 || deviceNum >= devices.length) {
      Log.writeln('No such device!');
      return;
    }
    Log.writeln('Listening to ${devices[deviceNum]}...');
    _port = await devices[deviceNum].create();
    if (stopped) {
      return;
    }
    if (!(await _port.open())) {
      Log.writeln('Failed to open device.');
      return;
    }
    if (stopped) {
      return;
    }
    await _port.setDTR(true);
    await _port.setRTS(true);
    Log.writeln(
        'Setting to baud ${settings.baudRate}, 8 databits, 1 stop bit, no parity');
    await _port.setPortParameters(settings.baudRate, UsbPort.DATABITS_8,
        UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);
    unawaited(_readStream(_port.inputStream));
  }

  @override
  void stop() {
    super.stop();
    try {
      _port.close();
      _port = null;
    } catch (ex) {
      Log.writeln('Error closing serial port:  $ex');
    }
  }
}

class HttpReader extends ByteStreamReader {
  HttpClient _client;
  bool _shutDownClient;
  final Uri uri;

  HttpReader(
      this._client, this.uri, Settings settings, StringStreamListener listener)
      : super(settings, listener) {
    _shutDownClient = _client == null;
    if (_shutDownClient) {
      _client = HttpClient();
    }
  }

  @override
  Future<void> start() async {
    final req = await _client.getUrl(uri);
    final Stream<List<int>> response = await req.close();
    unawaited(_readStream(response, onDone: () {
      unawaited(_reset());
    }));
  }

  @override
  void stop() {
    super.stop();
    if (_shutDownClient) {
      _client.close();
    }
  }
}

class ServerSocketReader extends ByteStreamReader {
  ServerSocket _serverSocket;
  Socket _readingFrom;

  ServerSocketReader(Settings settings, StringStreamListener listener)
      : super(settings, listener);

  @override
  Future<void> start() async {
    final localAddresses = await BreezyGlobals.getDeviceIPAddresses();
    if (stopped) {
      return;
    }
    Log.writeln('Listening to port ${settings.socketPort}');
    Log.writeln('    ${localAddresses.length} available network interface(s):');
    for (final s in localAddresses) {
      Log.writeln('        $s');
    }
    _serverSocket =
        await ServerSocket.bind(InternetAddress.anyIPv4, settings.socketPort);
    // anyIPv4 allows IPv6 too.
    // https://api.flutter.dev/flutter/dart-io/ServerSocket/bind.html
    if (stopped) {
      if (_serverSocket != null) {
        unawaited(_serverSocket.close());
        _serverSocket = null;
      }
      return;
    }
    InternetAddress lastAddress;
    _serverSocket.listen((Socket socket) {
      if (_readingFrom != null) {
        socket.add(utf8.encode('Already reading data from $lastAddress\r\n'));
        Log.writeln('Rejected connection from ${socket.address}');
        socket.destroy();
      } else {
        if (stopped) {
          socket.destroy();
        } else {
          _readingFrom = socket;
          lastAddress = socket.address;
          unawaited(_readStream(socket, onDone: () {
            socket.destroy();
            unawaited(_reset());
          }));
        }
      }
    });
  }

  Future<void> _reset() async {
    await super._reset();
    _readingFrom = null;
  }

  @override
  stop() {
    super.stop();
    if (_readingFrom != null) {
      _readingFrom.destroy();
      _readingFrom = null;
    }
    if (_serverSocket != null) {
      unawaited(_serverSocket.close());
      _serverSocket = null;
    }
  }

  void closeThisSocket() {
    _readingFrom?.destroy();
  }

  /// Send an informative message down the socket to our client
  Future<void> send(String msg) {
    final s = _readingFrom;
    if (s != null) {
      try {
        s.add(utf8.encode(msg));
        return s.flush();
      } catch (ex) {
        Log.writeln('$ex sending to socket');
      }
    }
    return Future<void>.value(null);
  }

  IOSink getSink() => _readingFrom;
}

class AssetFileReader extends ByteStreamReader {
  final BreezyConfiguration _config;

  AssetFileReader(Settings settings, this._config,
      StringStreamListener listener)
      : super(settings, listener);

  @override
  Future<void> start() async {
    List<String> log = await _config.getSampleLog();
    if (log.isEmpty) {
      throw Exception('Sample log is empty.');
    }
    while (!stopped) {
      await _readStream(_makeStream(log));
      // Just keep time marching forward, while looping through the data.
      await _reset();
    }
  }

  Stream<Uint8List> _makeStream(List<String> log) async* {
    for (final s in log) {
      yield Uint8List.fromList('$s\n'.codeUnits);
    }
  }
}

class BluetoothClassicReader extends ByteStreamReader {
  BluetoothClassicReader(Settings settings, StringStreamListener listener)
      : super(settings, listener);

  final fbs = FlutterBluetoothSerial.instance;

  @override
  Future<void> start() async {
    if (stopped) {
      return;
    }
    final device = await settings.getBluetoothClassicDevice();
    if (device == null) {
      Log.writeln('No Bluetooth Classic device selected.');
      Log.writeln('Please select one in Settings.');
      return;
    }
    try {
      while (!stopped) {
        Log.writeln('Connecting to ${device.name} (${device.address})...');
        BluetoothConnection conn =
            await BluetoothConnection.toAddress(device.address);
        await _readStream(conn.input, onDone: () {});
      }
    } catch (ex) {
      Log.writeln('Bluetooth error: $ex');
    }
  }

  @override
  stop() {
    super.stop();
  }
}
