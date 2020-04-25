import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'reader.dart';
import 'dart:async';
import 'package:pedantic/pedantic.dart' show unawaited;

import 'main.dart' show BreezyGlobals, InputSource, Log;
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

class InputTestPage extends StatefulWidget {
  final BreezyGlobals globals;
  final AssetBundle bundle;

  InputTestPage(this.globals, this.bundle, {Key key}) : super(key: key);

  @override
  _InputTestPageState createState() => _InputTestPageState();
}

class _InputTestPageState extends State<InputTestPage>
    implements Log, StringStreamListener {
  var _text = StringBuffer();
  static const _maxTextSize = 10000; // 10 K is more than enoough text.
  ByteStreamReader reader;
  DateTime pauseUntil;
  int bytesReceived = 0;
  Completer<void> _waitingForBuild;
  int lastWait = 0;
  bool stopped = false;

  @override
  void initState() {
    super.initState();
    Log.listeners.add(this);
    unawaited(startReader());
  }

  Future<void> startReader() async {
    if (stopped) {
      return;
    }
    switch (widget.globals.settings.inputSource) {
      case InputSource.serial:
        reader = SerialReader(widget.globals.settings, this);
        break;
      case InputSource.screenDebug:
        reader = null;
        break;
      case InputSource.sampleLog:
        reader = AssetFileReader(widget.globals.settings,
            widget.globals.configuration, this);
        break;
      case InputSource.serverSocket:
        reader = ServerSocketReader(widget.globals.settings, this);
        break;
      case InputSource.bluetoothClassic:
        reader = BluetoothClassicReader(widget.globals.settings, this);
        break;
      case InputSource.http:
        reader = HttpReader(null, Uri.parse(widget.globals.settings.httpUrl),
            widget.globals.settings, this);
        break;
    }
    if (reader == null) {
      Log.writeln();
      Log.writeln(
          "${widget.globals.settings.inputSource} doesn't produce text");
    } else {
      return reader.start();
    }
  }

  @override
  void dispose() {
    super.dispose();
    Log.listeners.remove(this);
    if (reader != null) {
      reader.stop();
    }
    stopped = true;
    _notifyBuild();
  }

  void _notifyBuild() {
    if (_waitingForBuild != null) {
      final w = _waitingForBuild;
      _waitingForBuild = null;
      w.complete(null);
    }
  }

  @override
  void notifyWriteln(Object o) {
    setState(() {
      _text.writeln(o.toString());
      _limitTextSize();
    });
  }

  void write(Object o) {
    setState(() {
      _text.write(o.toString());
      _limitTextSize();
    });
  }

  void _limitTextSize() {
    final int len = _text.length;
    if (len > (_maxTextSize + (_maxTextSize >> 1))) {
      // 50% too big is OK
      final int sz = _maxTextSize;
      StringBuffer sb = StringBuffer();
      sb.write(_text.toString().substring(len - sz, len));
      _text = sb;
    }
  }

  @override
  Widget build(BuildContext context) {
    _notifyBuild();
    return Scaffold(
        appBar: AppBar(title: Text('Breezy: Test Input'), actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Clear Text',
              onPressed: () => setState(() => _text = StringBuffer()))
        ]),
        body: Column(children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
                reverse: true,
                child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(_text.toString()))),
          )
        ]));
  }

  @override
  Future<void> receive(String input) async {
    bytesReceived += input.length;
    if (stopped) return;
    if (pauseUntil != null && DateTime.now().isBefore(pauseUntil)) {
      Log.writeln();
      Log.writeln('Pausing until $pauseUntil...');
      while (pauseUntil != null && DateTime.now().isBefore(pauseUntil)) {
        await Future.delayed(Duration(milliseconds: 250), () => null);
      }
      Log.writeln('Done pausing.');
      Log.writeln();
    }
    if (stopped) return;
    const waitEvery = 20000;
    if (bytesReceived - lastWait > waitEvery) {
      if (stopped) return;
      lastWait = bytesReceived;
      _waitingForBuild = Completer<void>();
    }
    write(input); // Doesn't go to log
    if (_waitingForBuild != null) {
      await _waitingForBuild.future;
      assert(_waitingForBuild == null); // Yes, I mean that.
      // Give the UI an extra tenth of a second.  It might help...
      await Future.delayed(Duration(milliseconds: 100), () => null);
    }
    // If the serial input is coming faster than the Android hardware can
    // handle, the following line should let the display task in often
    // enough to see some screen updates.  In production, data should never
    // come continuously and at full speed, because there's only one value
    // every 20ms.
  }

  @override
  Future<void> reset() async {
    if (bytesReceived > 0) {
      pauseUntil = DateTime.now().add(Duration(seconds: 10));
    }
  }
}
