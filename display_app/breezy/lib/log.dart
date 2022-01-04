/*
MIT License

Copyright (c) 2021 Bill Foote

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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jovial_misc/circular_buffer.dart';

abstract class Log {
  static void writeln([Object o = '']) {
    print(o);
    for (final l in listeners) {
      l.notifyWriteln(o);
    }
  }

  static final listeners = List<Log>();
  static bool _detailed = false;

  static bool get detailed => _detailed;

  void notifyWriteln(Object o);
}

class _InternalLog implements Log {
  CircularBuffer<String> lines;

  _InternalLog(int length, _InternalLog oldLog)
      : lines = CircularBuffer(List<String>.filled(length, "")) {
    if (oldLog != null) {
      for (int i = 0; i < oldLog.lines.length; i++) {
        lines.add(oldLog.lines[i]);
      }
    }
  }

  void notifyWriteln(Object o) => lines.add(o.toString());

  String getText() {
    final buf = StringBuffer();
    for (final line in lines) {
      buf.writeln(line);
    }
    return buf.toString();
  }
}

_InternalLog _currentLog = _InternalLog(0, null);

class LogScreen extends StatefulWidget {
  @override
  _LogScreenState createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final _logLinesText = TextEditingController();

  _LogScreenState();

  @override
  void initState() {
    super.initState();
    _logLinesText.text = _currentLog.lines.maxLines.toString();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Breezy: Logging'), actions: <Widget>[
          IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Clear',
              onPressed: () => setState(() {
                    _currentLog.lines.resetAndClear('');
                  })),
        ]),
        body: Column(children: [
          Row(children: [
            IconButton(
                icon: const Icon(Icons.copy_all),
                padding:
                    EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 8),
                tooltip: 'Copy Log to Paste Buffer',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _currentLog.getText()));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Copied ${_currentLog.lines.length} log line(s)')));
                }),
            SizedBox(width: 150,
            child:
            CheckboxListTile(
                title: const Text('Detailed'),
                value: Log._detailed,
                onChanged: (bool value) {
                  if (value != null) {
                    setState(() {
                      Log._detailed = value;
                    });
                  }
                })),
            SizedBox(width: 20),
            Expanded(
                child: TextField(
                    controller: _logLinesText,
                    onSubmitted: (s) => _setLogLength(s),
                    decoration: InputDecoration(labelText: "Log Lines"),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly])),
            SizedBox(width: 10),
          ]),
          Expanded(
              child: Padding(
                  padding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: InteractiveViewer(
                      scaleEnabled: false,
                      panEnabled: true,
                      constrained: false,
                      child: Align(
                          alignment: Alignment.topLeft,
                          child: Text(_currentLog.getText())))))
        ]));
  }

  void _setLogLength(String lenS) {
    var len = int.tryParse(lenS);
    if (len == null || len < 0) {
      len = 0;
    }
    final newLog = _InternalLog(len, _currentLog);
    Log.listeners.remove(_currentLog); // NOP if not there, e.g. zero length
    if (len > 0) {
      Log.listeners.add(newLog);
    }
    setState(() {
      _currentLog = newLog;
      _logLinesText.text = _currentLog.lines.maxLines.toString();
    });
  }
}
