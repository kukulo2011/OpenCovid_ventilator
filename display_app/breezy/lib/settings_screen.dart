import 'package:flutter/material.dart';
import 'main.dart'
    show Settings, SettingsListener, InputSource, UUID, BreezyGlobals;
import 'package:usb_serial/usb_serial.dart' show UsbSerial, UsbDevice;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    show BluetoothDevice;

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

class SettingsScreen extends StatefulWidget {
  final Settings _settings;
  final BreezyGlobals globals;
  final List<UsbDevice> usbDevices = List<UsbDevice>();
  final List<BluetoothDevice> bluetoothClassicDevices;

  SettingsScreen(this.globals)
      : this._settings = globals.settings,
        this.bluetoothClassicDevices = globals.bluetoothClassicDevices;

  Future<void> init() async {
    usbDevices.clear();
    usbDevices.addAll(await UsbSerial.listDevices());
    await globals.checkNeighborhood();
  }

  @override
  _SettingsScreenState createState() => _SettingsScreenState(_settings);
}

class _SettingsScreenState extends State<SettingsScreen>
    implements SettingsListener {
  final Settings settings;
  TextEditingController _socketPortController;
  TextEditingController _securityStringController;

  _SettingsScreenState(this.settings);

  @override
  void initState() {
    super.initState();
    settings.listeners.add(this);
    _socketPortController = TextEditingController();
    _socketPortController.text = settings.socketPort.toString();
    _socketPortController.addListener(() {
      try {
        int port = int.parse(_socketPortController.text);
        settings.socketPort = port;
      } catch (ex) {
        _socketPortController.text = settings.socketPort.toString();
      }
    });
    _securityStringController = TextEditingController();
    _securityStringController.value =
        _securityStringController.value.copyWith(text: settings.securityString);
  }

  @override
  void dispose() {
    super.dispose();
    settings.listeners.remove(this);
    String s = _securityStringController.text.trim();
    if (s != '') {
      settings.securityString = s;
    } else {
      settings.securityString = UUID.random().toString();
    }
    _socketPortController.dispose();
    _securityStringController.dispose();
  }

  String deviceName(InputSource s) {
    switch (s) {
      case InputSource.serial:
        return 'USB Serial Port';
      case InputSource.screenDebug:
        return 'Screen Debug Functions';
      case InputSource.sampleLog:
        return 'Demo Log Data';
      case InputSource.serverSocket:
        return 'Socket Connection to This Device';
      case InputSource.bluetoothClassic:
        return 'Bluetooth Classic/RFCOMM';
    }
    return null; // Shut up dart lint
  }

  @override
  Widget build(BuildContext context) {
    bool meterIsMeaningful = false;
    final menuItems = List<Widget>();
    menuItems.add(Row(children: [
      Text('Input:  '),
      DropdownButton<InputSource>(
          value: settings.inputSource,
          items: [
            InputSource.serial,
            InputSource.bluetoothClassic,
            InputSource.serverSocket,
            InputSource.sampleLog,
            InputSource.screenDebug
          ]
              .map((src) =>
                  DropdownMenuItem(value: src, child: Text(deviceName(src))))
              .toList(growable: false),
          onChanged: (InputSource v) {
            settings.inputSource = v;
          })
    ]));
    switch (settings.inputSource) {
      case InputSource.serial:
        {
          final items = List<DropdownMenuItem<int>>();
          if (widget.usbDevices.isEmpty) {
            items.add(DropdownMenuItem(value: 0, child: Text('None Detected')));
          }
          for (int i = 1; i <= widget.usbDevices.length; i++) {
            items.add(DropdownMenuItem(
                value: i,
                child: Text(
                    '${i}:  Device ID ${widget.usbDevices[i - 1].deviceId}')));
          }
          menuItems.add(Row(children: [
            Text('Port:  '),
            DropdownButton<int>(
                value: settings.serialPortNumber,
                items: items,
                onChanged: (v) => settings.serialPortNumber = v)
          ]));
        }
        menuItems.add(Row(children: [
          Text('Baud Rate:  '),
          DropdownButton<int>(
              value: settings.baudRate,
              onChanged: (v) => settings.baudRate = v,
              items: [2400, 9600, 19200, 38400, 57600, 115200]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(growable: false))
        ]));
        meterIsMeaningful = true;
        break;
      case InputSource.screenDebug:
        // Nothing special here
        break;
      case InputSource.sampleLog:
        // Nothing special here
        break;
      case InputSource.serverSocket:
        menuItems.add(Row(children: [
          Text('Server Socket Port number:'),
          SizedBox(width: 16),
          Expanded(
              child: TextField(
                  keyboardType: TextInputType.number,
                  autocorrect: false,
                  controller: _socketPortController)),
        ]));
        menuItems.add(
          Row(children: [
            Text('Security string (blank for random):'),
            SizedBox(width: 16),
            Expanded(
                child: TextField(
                    autocorrect: false, controller: _securityStringController)),
          ]),
        );
        meterIsMeaningful = true;
        break;
      case InputSource.bluetoothClassic:
        {
          final items = widget.bluetoothClassicDevices
              .map((d) => DropdownMenuItem(
                  value: d, child: Text('${d.name}  ${d.address}')))
              .toList(growable: true);
          if (items.isEmpty) {
            items.add(DropdownMenuItem<BluetoothDevice>(
                value: null, child: Text('No paired devices found.')));
          } else {
            items.insert(
                0,
                DropdownMenuItem<BluetoothDevice>(
                    value: null, child: Text('none')));
          }
          menuItems.add(Row(children: [
            Text('Device:  '),
            DropdownButton<BluetoothDevice>(
                value: settings.bluetoothClassicDevice,
                onChanged: (v) => settings.bluetoothClassicDevice = v,
                items: items)
          ]));
        }
        meterIsMeaningful = true;
        break;
    }
    if (meterIsMeaningful) {
      menuItems.add(CheckboxListTile(
        title: const Text('Meter Incoming Data by Timestamp'),
        value: settings.meterData,
        onChanged: (v) => settings.meterData = v,
        secondary: const Icon(Icons.access_time)
      ));
    }
    return WillPopScope(
      onWillPop: () async {
        await settings.write();
        return true;
      },
      child: Scaffold(
          appBar: AppBar(title: Text('Breezy Settings')),
          body: SingleChildScrollView(
              padding: EdgeInsets.all(5),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: menuItems))),
    );
  }

  @override
  void settingsChanged() {
    setState(() {});
  }
}
