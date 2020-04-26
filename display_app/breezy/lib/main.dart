import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle;
import 'package:pedantic/pedantic.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity/connectivity.dart'
    show Connectivity, ConnectivityResult;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    show BluetoothDevice, FlutterBluetoothSerial;
import 'dart:io' show exit, File, Directory, NetworkInterface;
import 'dart:convert' as convert;
import 'utils.dart';
import 'input_test.dart';
import 'graphs_screen.dart';
import 'read_device.dart';
import 'settings_screen.dart';
import 'configure.dart' as config;
import 'configure_a.dart' as config;

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

abstract class Log {
  // TODO:  Send this to an internal buffer, so we can access it from a menu
  static void writeln([Object o = '']) {
    print(o);
    for (final l in listeners) {
      l.notifyWriteln(o);
    }
  }

  static final listeners = List<Log>();

  void notifyWriteln(Object o);
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // debugShowCheckedModeBanner: false,
      title: 'Breezy Display',
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

/// Potentially mutable global state for the app.  This could just be held
/// in static variables scattered around, but I like maintaining it
/// centrally, and passing it down the tree.  Old habit, perhaps.
class BreezyGlobals {
  final Settings settings = Settings();
  config.BreezyConfiguration configuration;

  static Future<List<String>> getDeviceIPAddresses() async {
    final result = List<String>();
    if (NetworkInterface.listSupported) {
      // false in Android as of this writing :-(
      final List<NetworkInterface> ifs = await NetworkInterface.list();
      for (final i in ifs) {
        for (final a in i.addresses) {
          result.add(a.toString());
        }
      }
      if (result.isEmpty) {
        result.add('No local IP address found');
      }
    } else {
      final conn = Connectivity();
      switch (await conn.checkConnectivity()) {
        case ConnectivityResult.wifi:
          result.add(await conn.getWifiIP());
          break;
        case ConnectivityResult.mobile:
          result.add('Moblie network, address unknown');
          break;
        case ConnectivityResult.none:
          result.add('No local IP address found');
          break;
      }
    }
    return result;
  }

  static Future<List<BluetoothDevice>> getBluetoothClassicDevices() async {
    final result = List<BluetoothDevice>();
    try {
      List<BluetoothDevice> devices =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      result.addAll(devices);
      result.sort((d1, d2) {
        int r = 0;
        if (d1.name != null && d2.name != null) {
          // This probably never happens - I imagine the library gives
          // an empty string, and not a null, if the name isn't set.
          r = d1.name.toLowerCase().compareTo(d2.name.toLowerCase());
        }
        if (r == 0) {
          r = d1.address.compareTo(d2.address);
          // If two devices have the same name, this ensures a consistent order.
        }
        return r;
      });
    } catch (ex) {
      Log.writeln('Attempt to get bluetooth devices failed with $ex');
    }
    return result;
  }
}

class _BreezyHomePageState extends State<BreezyHomePage>
    implements SettingsListener {
  final globals = BreezyGlobals();
  String settingsString = '';
  Completer<void> _waitingForInit;

  @override
  void initState() {
    super.initState();
    globals.settings.listeners.add(this);
  }

  Future<void> asyncInit(AssetBundle bundle) async {
    if (_waitingForInit != null) {
      await _waitingForInit.future;
    } else {
      _waitingForInit = Completer<void>();
      Directory dir = await getApplicationSupportDirectory();
      config.AndroidBreezyConfiguration.localStorage = Directory('${dir.path}/config');
      config.AndroidBreezyConfiguration.assetBundle = bundle;
      Settings.settingsFile = File("${dir.path}/settings.json");
      await globals.settings.read(globals);
      final name = globals.settings.configurationName;
      if (name == null) {
        globals.configuration = config.DefaultBreezyConfiguration.defaultConfig;
      } else {
        try {
          final c = await config.JsonBreezyConfiguration.read(name);
          if (c.name != name) {
            throw Exception('Configuration name mismatch:  $name != ${c.name}');
          }
          globals.configuration = c;
        } catch (ex, st) {
          print('Error reading configuration $name!');
          print(st);
          print(ex);
          // Unless someone manually deletes a config file, this shouldn't
          // happen.
          globals.configuration = config.DefaultBreezyConfiguration.defaultConfig;
          globals.settings.configurationName = null;

        }
      }
      _waitingForInit.complete(null);
    }
    settingsString = await globals.settings.forUI(globals);
  }

  @override
  void dispose() {
    super.dispose();
    globals.settings.listeners.remove(this);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: asyncInit(DefaultAssetBundle.of(context)),
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
                          DeviceDataSource src = _createDataSource(context);
                          unawaited(_showGraphsScreen(src));
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
                                  builder: (context) => InputTestPage(globals,
                                      DefaultAssetBundle.of(context))));
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
                          var ss = SettingsScreen(globals);
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
                          Text('Show Graph Screen'),
                          const SizedBox(width: 20),
                          Icon(Icons.timeline, color: Colors.black)
                        ]),
                        onPressed: () async {
                          DeviceDataSource src = _createDataSource(context);
                          unawaited(_showGraphsScreen(src));
                        }),
                    Spacer(),
                  ],
                ),
                const SizedBox(height: 50),
                Text(settingsString)
              ],
            ),
          ),
        ));
  }

  DeviceDataSource _createDataSource(BuildContext context) {
    switch (globals.settings.inputSource) {
      case InputSource.serial:
        try {
          return DeviceDataSource.fromSerial(
              globals.settings, globals.configuration);
        } catch (ex) {
          Scaffold.of(context).showSnackBar(
              SnackBar(content: Text('Error with serial port:  $ex')));
        }
        break;
      case InputSource.sampleLog:
        return DeviceDataSource.fromSampleLog(globals);
      case InputSource.screenDebug:
        return DeviceDataSource.screenDebug(globals.configuration);
      case InputSource.http:
        return DeviceDataSource.http(globals.settings, globals.configuration);
      case InputSource.serverSocket:
        return DeviceDataSource.serverSocket(
            globals, DefaultAssetBundle.of(context));
      case InputSource.bluetoothClassic:
        return DeviceDataSource.bluetoothClassic(globals);
    }
    return null;
  }

  Future<void> _showGraphsScreen(DeviceDataSource src) async {
    while (src != null) {
      src = await Navigator.push<DeviceDataSource>(
        context,
        MaterialPageRoute(
          builder: (context) => GraphsScreen(
            dataSource: src,
            globals: globals)));
    }
  }

  @override
  void settingsChanged() {
    scheduleMicrotask(() => setState(() {}));
  }
}

enum InputSource {
  serial,
  screenDebug,
  sampleLog,
  http,
  serverSocket,
  bluetoothClassic
}

abstract class SettingsListener {
  void settingsChanged();
}

/// Settings that we persist.
class Settings {
  static File settingsFile;
  final listeners = List<SettingsListener>();
  InputSource _inputSource = InputSource.sampleLog;
  String _httpUrl = 'https://breezy-display.jovial.com/weather_demo.breezy';
  int _serialPortNumber = 1;
  int _baudRate = 115200;
  int _socketPort = 7777;
  String _securityString = UUID.random().toString();
  bool _meterData = false;
  String _bluetoothClassicAddress;
  String _configurationName;

  Settings();

  Future<void> read(BreezyGlobals globals) async {
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
      v = json['httpUrl'];
      if (v != null) {
        _httpUrl = v as String;
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
      v = json['bluetoothClassicDevice'];
      if (v != null) {
        _bluetoothClassicAddress = v as String;
      }
      v = json['configurationName'];
      if (v != null) {
        _configurationName = v as String;
      }
    }
  }

  Future<void> write() async {
    final json = {
      'inputSource': _inputSource.toString(),
      'httpUrl' : _httpUrl,
      'serialPortNumber': _serialPortNumber,
      'baudRate': _baudRate,
      'meterData': _meterData,
      'socketPort': _socketPort,
      'securityString': _securityString,
      'bluetoothClassicDevice': _bluetoothClassicAddress,
      'configurationName': _configurationName
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

  String get httpUrl => _httpUrl;
  set httpUrl(String v) {
    _httpUrl = v;
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
    if (v == InputSource.screenDebug || v == InputSource.sampleLog) {
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

  String get configurationName => _configurationName;

  set configurationName(String v) {
    _configurationName = v;
    _notify();
  }

  String get bluetoothClassicAddress => _bluetoothClassicAddress;

  set bluetoothClassicAddress(String d) {
    _bluetoothClassicAddress = d; // null OK
    _notify();
  }

  Future<BluetoothDevice> getBluetoothClassicDevice() async =>
      (await BreezyGlobals.getBluetoothClassicDevices()).firstWhere(
          (d) => d.address == bluetoothClassicAddress,
          orElse: () => null);

  Future<String> forUI(BreezyGlobals globals) async {
    final result = StringBuffer();
    result.writeln("Settings:");
    result.writeln();
    if (configurationName != null) {
      result.writeln('    Configuration:  $configurationName');
    }
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
      case InputSource.sampleLog:
        result.writeln('    Input from sample log file');
        break;
      case InputSource.http:
        result.writeln('    Input from $httpUrl');
        result.writeln(
          '        meter incoming data by time:  $meterData');
        break;
      case InputSource.serverSocket:
        {
          final localAddresses = await BreezyGlobals.getDeviceIPAddresses();
          result.writeln('    Input from socket connection');
          result.writeln('    Connect to port:  $socketPort');
          result.writeln('    First line of input must be "$securityString"');
          result.writeln(
              '        meter incoming data by time:  $meterData');
          result.writeln(
              '    ${localAddresses.length} available network interface(s):');
          for (final s in localAddresses) {
            result.writeln('        $s');
          }
          break;
        }
      case InputSource.bluetoothClassic:
        {
          BluetoothDevice d = await getBluetoothClassicDevice();
          result.writeln('    Bluetooth Classic/RFCOMM');
          result.writeln('    Device:  ${d?.name ?? 'none'}');
          break;
        }
    }
    return result.toString();
  }
}

Future<void> showErrorDialog(BuildContext context, String message, Object exception) => showDialog(
    context: context,
    builder: (BuildContext context) {
      String exs = 'Error';
      try {
        exs = exception.toString();
      } catch (ex) {
        print('Error in exception.toString()');
      }
      // return object of type Dialog
      return AlertDialog(
        title: Text(message),
        content: SingleChildScrollView(
          child: Column(children: [
            SizedBox(height: 20),
            Text(exs),
          ]),
        ),
        actions: <Widget>[
          // usually buttons at the bottom of the dialog
          FlatButton(
            child: Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          )
        ],
      );
    },
  );
