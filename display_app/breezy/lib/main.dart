import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity/connectivity.dart'
    show Connectivity, ConnectivityResult;
import 'dart:io' show exit, stdout, File, Directory, NetworkInterface;
import 'dart:convert' as convert;
import 'dart:math' show Random;
import 'serial_test.dart';
import 'graphs_screen.dart';
import 'read_device.dart';
import 'settings_screen.dart';
import 'configure.dart' as config;

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

class BreezyGlobals {
  final Settings settings = Settings();
  config.BreezyConfiguration configuration =
      config.BreezyConfiguration.defaultConfig;
  final deviceAddresses = List<String>();
}

class _BreezyHomePageState extends State<BreezyHomePage>
    implements SettingsListener {
  final globals = BreezyGlobals();

  @override
  void initState() {
    super.initState();
    globals.settings.listeners.add(this);
  }

  Future<void> asyncInit() async {
    if (Settings.settingsFile == null) {
      Directory dir = await getApplicationSupportDirectory();
      Settings.settingsFile = File("${dir.path}/settings.json");
      await globals.settings.read();
    }
    globals.deviceAddresses.clear();
    if (NetworkInterface.listSupported) {
      // false in Android as of this writing :-(
      final List<NetworkInterface> ifs = await NetworkInterface.list();
      for (final i in ifs) {
        for (final a in i.addresses) {
          globals.deviceAddresses.add(a.toString());
        }
      }
      if (globals.deviceAddresses.isEmpty) {
        globals.deviceAddresses.add('No local IP address found');
      }
    } else {
      final conn = Connectivity();
      final result = await conn.checkConnectivity();
      switch (result) {
        case ConnectivityResult.wifi:
          globals.deviceAddresses.add(await conn.getWifiIP());
          break;
        case ConnectivityResult.mobile:
          globals.deviceAddresses.add('Moblie network, address unknown');
          break;
        case ConnectivityResult.none:
          globals.deviceAddresses.add('No local IP address found');
          break;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    globals.settings.listeners.remove(this);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: asyncInit(),
        builder: (context, snapshot) {
          return doBuild(context);
        });
  }

  Widget doBuild(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: Image.asset('assets/breeze_icon_white_256x256.png'),
          title: Text(widget._title),
          actions: <Widget>[
            PopupMenuButton<void Function()>(
                // icon: Icon(Icons.menu),
                // tooltip: 'Menu',
                onSelected: (f) => f(),
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<void Function()>(
                        value: () {
                          DeviceDataSource src = _createDataSource(
                              globals.configuration.feed, context);
                          if (src != null) {
                            Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => GraphsScreen(
                                        // dataSource: DeviceDataSource.screenDebug()
                                        dataSource: src)));
                          }
                        },
                        child: Row(
                          children: <Widget>[
                            Text('Show Graph Screeen'),
                            Spacer(),
                            Icon(Icons.timeline, color: Colors.black)
                          ],
                        )),
                    PopupMenuItem<void Function()>(
                        value: () {
                          Navigator.push<void>(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      SerialTestPage(globals.settings)));
                        },
                        child: Row(
                          children: <Widget>[
                            Text('Test Input Port'),
                            Spacer(),
                            Icon(Icons.pageview, color: Colors.black)
                          ],
                        )),
                    PopupMenuItem<void Function()>(
                        value: () async {
                          var ss = SettingsScreen(globals.settings);
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
          builder: (context) => SingleChildScrollView(
            padding: EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 40),
                Row(
                  children: <Widget>[
                    Spacer(),
                    RaisedButton(
                        child: Row(children: <Widget>[
                          Text('Show Graph Screeen'),
                          const SizedBox(width: 20),
                          Icon(Icons.timeline, color: Colors.black)
                        ]),
                        onPressed: () async {
                          DeviceDataSource src = _createDataSource(
                              globals.configuration.feed, context);
                          if (src != null) {
                            unawaited(Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => GraphsScreen(
                                        // dataSource: DeviceDataSource.screenDebug()
                                        dataSource: src))));
                          }
                        }),
                    Spacer(),
                  ],
                ),
                const SizedBox(height: 50),
                Text('${globals.settings.forUI(globals.deviceAddresses)}')
              ],
            ),
          ),
        ));
  }

  DeviceDataSource _createDataSource(
      config.DataFeed feed, BuildContext context) {
    switch (globals.settings.inputSource) {
      case InputSource.serial:
        try {
          return DeviceDataSource.fromSerial(
              globals.settings, globals.configuration.feed);
        } catch (ex) {
          Scaffold.of(context).showSnackBar(
              SnackBar(content: Text('Error with serial port:  $ex')));
        }
        break;
      case InputSource.assetFile:
        return DeviceDataSource.fromAssetFile(
            feed, DefaultAssetBundle.of(context), "assets/demo.log");
      case InputSource.screenDebug:
        return DeviceDataSource.screenDebug(globals.configuration.feed);
      case InputSource.serverSocket:
        return DeviceDataSource.serverSocket(
            globals.settings, globals.configuration.feed);
    }
    return null;
  }

  @override
  void settingsChanged() {
    setState(() {});
  }
}

enum InputSource { serial, screenDebug, assetFile, serverSocket }

abstract class SettingsListener {
  void settingsChanged();
}

class Settings {
  static File settingsFile;
  final listeners = List<SettingsListener>();
  InputSource _inputSource = InputSource.assetFile;
  int _serialPortNumber = 1;
  int _baudRate = 115200;
  int _socketPort = 7777;
  String _securityString = UUID.random().toString();
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
      v = json['socketPort'];
      if (v != null) {
        _socketPort = v as int;
      }
      v = json['securityString'];
      if (v != null) {
        _securityString = v as String;
      }
    }
  }

  Future<void> write() async {
    final json = {
      'inputSource': _inputSource.toString(),
      'serialPortNumber': _serialPortNumber,
      'baudRate': _baudRate,
      'meterData': _meterData,
      'socketPort': _socketPort,
      'securityString': _securityString
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
    assert(v != null);
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
    assert(v != null);
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
    assert(v != null);
    _meterData = v;
    _notify();
  }

  int get socketPort => _socketPort;

  set socketPort(int v) {
    assert(v != null);
    _socketPort = v;
    _notify();
  }

  String get securityString => _securityString;

  set securityString(String v) {
    assert(v != null);
    _securityString = v;
    _notify();
  }

  String forUI(List<String> localAddresses) {
    final result = StringBuffer();
    result.writeln("Settings:");
    result.writeln();
    switch (inputSource) {
      case InputSource.serial:
        result.writeln('    Input from serial port $serialPortNumber');
        result.writeln('        Baud rate:  $baudRate');
        result.writeln('        eight data bits, one stop bit, no parity');
        result.writeln(
            '    meter incoming data by time (for debug):  $meterData');
        break;
      case InputSource.screenDebug:
        result.writeln('    Input from internal demo functions');
        break;
      case InputSource.assetFile:
        result.writeln('    Input from sample log file');
        break;
      case InputSource.serverSocket:
        result.writeln('    Input from socket connection');
        result.writeln('    Connect to port:  $socketPort');
        result.writeln('    First line of input must be "$securityString"');
        result.writeln(
            '        meter incoming data by time (for debug):  $meterData');
        result.writeln(
            '    ${localAddresses.length} available network interface(s):');
        for (final s in localAddresses) {
          result.writeln('        $s');
        }
    }
    return result.toString();
  }
}

/// A minimal implementation of v4 UUIDs.
/// cf. https://tools.ietf.org/html/rfc4122
class UUID {
  final int time_low; // 4 bytes
  final int time_mid; // 2 bytes
  final int time_hi_and_version; // 2 bytes
  final int clock_seq_hi_and_reserved; // 1 byte
  final int clock_seq_low; // 1 byte
  final int node; // 6 bytes

  static final Random _random = Random.secure();

  /// Generate a random (v4) UUID
  UUID.random()
      : clock_seq_hi_and_reserved = 0x80 | _random.nextInt(0x40),
        time_hi_and_version = 0x4000 | _random.nextInt(0x1000),
        time_low = _random.nextInt(0x100000000),
        time_mid = _random.nextInt(0x10000),
        clock_seq_low = _random.nextInt(0x100),
        node = (_random.nextInt(0x10000) << 8) | _random.nextInt(0x100000000);

  String toString() {
    return _toHex(time_low, 8) +
        '-' +
        _toHex(time_mid, 4) +
        '-' +
        _toHex(time_hi_and_version, 4) +
        '-' +
        _toHex(clock_seq_hi_and_reserved, 2) + // no dash
        _toHex(clock_seq_low, 2) +
        '-' +
        _toHex(node, 12);
  }

  String _toHex(int value, int digits) {
    String s = value.toRadixString(16);
    const String zeros = '0000000000000000'; // Enough for 64 bits
    return zeros.substring(0, digits - s.length) + s;
  }
}
