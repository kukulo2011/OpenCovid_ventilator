import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';
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

class SerialTestPage extends StatefulWidget {
  SerialTestPage({Key key}) : super(key: key);

  @override
  _SerialTestPageState createState() => _SerialTestPageState();
}

class _SerialTestPageState extends State<SerialTestPage> {
  var _text = StringBuffer();

  @override
  void initState() {
    super.initState();
    unawaited(_startListeningToPort());
  }

  void _println(Object o) {
    setState(() => _text.writeln(o.toString()));
  }

  void _print(Object o) {
    setState(() => _text.write(o.toString()));
  }

  Future<void> _startListeningToPort() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    _println("${devices.length} devices seen");
    for (var d in devices) {
      _println("  $d");
    }
    if (devices.isEmpty) {
      return;
    }
    _println("Listening to ${devices[0]}...");
    final UsbPort port = await devices[0].create();
    if (!(await port.open())) {
      _println("Failed to open device.");
    }
    await port.setDTR(true);
    await port.setRTS(true);
    await port.setPortParameters(9600, UsbPort.DATABITS_8, UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE);
    port.inputStream.listen((Uint8List event) {
      final b = StringBuffer();
      for (final ch in event) {
        b.writeCharCode(ch);
      }
      _print(b.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Breezy: Test Serial'),
            actions: <Widget>[
              IconButton(
                  icon: Icon(Icons.delete),
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
}
