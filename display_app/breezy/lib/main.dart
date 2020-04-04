import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io' show exit, stdout, File, Directory;
import 'dart:convert' as convert;
import 'serial_test.dart';
import 'graphs_screen.dart';
import 'read_device.dart';
import 'settings_screen.dart';
import 'spec.dart' as spec show DataFeed;

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

void main() async {
  runApp(MyApp());
}

class Log {
  // TODO:  Send this to an internal buffer, so we can access it from a menu
  static void writeln([Object o = '']) => stdout.writeln(o);
  static void write(Object o) => stdout.write(o);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // debugShowCheckedModeBanner: false,
      title: 'Breezy Prototype',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BreezyHomePage(title: 'Breezy Home Page'),
    );
  }
}

class BreezyHomePage extends StatefulWidget {
  final String _title;

  BreezyHomePage({Key key, String title})
      : this._title = title,
        super(key: key);

  @override
  _BreezyHomePageState createState() => _BreezyHomePageState();
}

class _BreezyHomePageState extends State<BreezyHomePage>
    implements SettingsListener {
  final Settings settings = Settings();

  @override
  void initState() {
    super.initState();
    settings.listeners.add(this);
  }

  Future<void> readSettings() async {
    if (Settings.settingsFile == null) {
      Directory dir = await getApplicationSupportDirectory();
      Settings.settingsFile = File("${dir.path}/settings.json");
      await settings.read();
    }
  }

  @override
  void dispose() {
    super.dispose();
    settings.listeners.remove(this);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: readSettings(),
      builder: (context, snapshot) {
        return doBuild(context);
      }
    );
  }
  Widget doBuild(BuildContext context) {
    const bigTextStyle = TextStyle(fontSize: 20);
    return Scaffold(
        appBar: AppBar(
          title: Text(widget._title),
          actions: <Widget>[
            PopupMenuButton<void Function()>(
                // icon: Icon(Icons.menu),
                // tooltip: 'Menu',
                onSelected: (f) => f(),
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<void Function()>(
                        value: () async {
                          var ss = SettingsScreen(settings);
                          await ss.init();
                          unawaited(Navigator.push<void>(context,
                              MaterialPageRoute(builder: (context) => ss)));
                        },
                        child: Row(
                          children: <Widget>[
                            Text('Settings'),
                            Spacer(),
                            Icon(Icons.settings, color: Colors.black)
                          ],
                        )),
                    PopupMenuItem(
                        value: () => exit(0),
                        child: Row(children: [
                          Text('Quit'),
                          Spacer(),
                          Icon(Icons.power_settings_new, color: Colors.black),
                        ])),
                  ];
                }
//              icon: Icon(Icons.power_settings_new),
//              tooltip: 'Quit',
//              onPressed: () { exit(0); }
                )
          ],
        ),
        body: Builder(
          builder: (context) => Center(
              child: Column(children: <Widget>[
            const SizedBox(height: 50),
            RaisedButton(
                child:
                    const Text('Test Serial Connection', style: bigTextStyle),
                onPressed: () {
                  Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SerialTestPage(settings)));
                }),
            const SizedBox(height: 30),
            RaisedButton(
                child: const Text('Show Graph Screen', style: bigTextStyle),
                onPressed: () async {
                  DeviceDataSource src = _createDataSource(context);
                  if (src != null) {
                    unawaited(Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                            builder: (context) => GraphsScreen(
                                // dataSource: DeviceDataSource.screenDebug()
                                dataSource: src))));
                  }
                }),
          ])),
        ));
  }

  DeviceDataSource _createDataSource(BuildContext context) {
    switch (settings.inputSource) {
      case InputSource.serial:
        try {
          return DeviceDataSource.fromSerial(settings);
        } catch (ex) {
          Scaffold.of(context).showSnackBar(
              SnackBar(content: Text('Error with serial port:  $ex')));
        }

        break;
      case InputSource.assetFile:
        return DeviceDataSource.fromAssetFile(
            DefaultAssetBundle.of(context), "assets/demo.log");
      case InputSource.screenDebug:
        return DeviceDataSource.screenDebug(settings);
    }
    return null;
  }

  @override
  void settingsChanged() {
    setState(() {});
  }
}

enum InputSource { serial, screenDebug, assetFile }
// NB:  Index is written in JSON format

abstract class SettingsListener {
  void settingsChanged();
}

class Settings {
  static File settingsFile;
  final listeners = List<SettingsListener>();
  InputSource _inputSource = InputSource.assetFile;
  int _serialPortNumber = 1;
  int _baudRate = 115200;
  bool _meterData = true;

  Settings();

  Future<void> read() async {
    if (await settingsFile.exists()) {
      final str = await settingsFile.readAsString();
      final dynamic json = convert.json.decode(str);
      dynamic v = json['inputSource'];
      for (final e in InputSource.values) {
        if (e.toString() == v) {
          _inputSource = e;
        }
      }
      v = json['serialPortNumber'];
      if (v != null) {
        _serialPortNumber = v as int;
      }
      v = json['baudRate'];
      if (v != null) {
        _baudRate = v as int;
      }
      v = json['meterData'];
      if (v != null) {
        _meterData = v as bool;
      }
    }
  }

  Future<void> write() async {
    final json = {
      'inputSource' : _inputSource.toString(),
      'serialPortNumber' : _serialPortNumber,
      'baudRate' : _baudRate,
      'meterData' : _meterData
    };
    final str = convert.json.encode(json);
    await settingsFile.writeAsString(str);
  }

  void _notify() {
    for (var w in listeners) {
      w.settingsChanged();
    }
  }

  InputSource get inputSource => _inputSource;
  set inputSource(InputSource v) {
    _inputSource = v;
    _notify();
  }

  /// 1..n, or 0 if none selected
  int get serialPortNumber => _serialPortNumber;
  set serialPortNumber(int v) {
    _serialPortNumber = v;
    _notify();
  }

  int get baudRate => _baudRate;
  set baudRate(int v) {
    _baudRate = v;
    _notify();
  }

  bool get meterData {
    final v = _inputSource;
    if (v == InputSource.screenDebug || v == InputSource.assetFile) {
      return true;
    } else {
      return _meterData;
    }
  }
  set meterData(bool v) {
    _meterData = v;
    _notify();
  }

  // TODO:  Get from current application spec, and remove from here.
  final spec.DataFeed dataFeedSpec = spec.DataFeed.defaultFeed;
}
