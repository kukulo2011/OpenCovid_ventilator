import 'package:flutter/material.dart';
import 'main.dart' show Settings, SettingsListener, InputSource, UUID;
import 'package:usb_serial/usb_serial.dart' show UsbSerial, UsbDevice;

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
  final List<UsbDevice> devices = List<UsbDevice>();

  SettingsScreen(this._settings);

  Future<void> init() async {
    devices.clear();
    devices.addAll(await UsbSerial.listDevices());
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
    _securityStringController.value = _securityStringController.value.copyWith(
        text: settings.securityString,
        selection: TextSelection(
            baseOffset: 0, extentOffset: settings.securityString.length));
    _securityStringController.addListener(() {
      String s = _securityStringController.text.trim();
      if (s != '') {
        settings.securityString = s;
      } else {
        settings.securityString = UUID.random().toString();
        _securityStringController.value = _securityStringController.value
            .copyWith(
                text: settings.securityString,
                selection: TextSelection(
                    baseOffset: 0,
                    extentOffset: settings.securityString.length));
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    settings.listeners.remove(this);
    _socketPortController.dispose();
    _securityStringController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSerial = settings.inputSource == InputSource.serial;
    final isSocket = settings.inputSource == InputSource.serverSocket;
    return WillPopScope(
      onWillPop: () async {
        await settings.write();
        return true;
      },
      child: Scaffold(
          appBar: AppBar(
            title: Text('Breezy Settings')),
          body: SingleChildScrollView(
              padding: EdgeInsets.all(5),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Input source:',
                        style: Theme.of(context).textTheme.subhead),
                    RadioListTile<InputSource>(
                        title: const Text('USB Serial Port'),
                        value: InputSource.serial,
                        groupValue: settings.inputSource,
                        onChanged: (v) => settings.inputSource = v),
                    RadioListTile<InputSource>(
                        title: const Text('Socket Connection to This Device'),
                        value: InputSource.serverSocket,
                        groupValue: settings.inputSource,
                        onChanged: (v) => settings.inputSource = v),
                    RadioListTile<InputSource>(
                        title: const Text('Demo Log Data'),
                        value: InputSource.assetFile,
                        groupValue: settings.inputSource,
                        onChanged: (v) => settings.inputSource = v),
                    RadioListTile<InputSource>(
                        title: const Text('Screen Debug Functions'),
                        value: InputSource.screenDebug,
                        groupValue: settings.inputSource,
                        onChanged: (v) => settings.inputSource = v),
                    PopupMenuButton<int>(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16.0),
                          title: Text(
                              'Serial Port number ${settings.serialPortNumber}',
                              style: Theme.of(context).textTheme.title.merge(
                                  isSerial
                                      ? null
                                      : const TextStyle(color: Colors.grey))),
                        ),
                        onSelected: (v) => settings.serialPortNumber = v,
                        enabled: isSerial,
                        itemBuilder: _buildSerialPortMenu),
                    PopupMenuButton<int>(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16.0),
                          title: Text('Baud rate ${settings.baudRate}',
                              style: Theme.of(context).textTheme.title.merge(
                                  isSerial
                                      ? null
                                      : const TextStyle(color: Colors.grey))),
                        ),
                        onSelected: (v) => settings.baudRate = v,
                        enabled: isSerial,
                        itemBuilder: (context) => const [
                              PopupMenuItem(value: 2400, child: Text('2400')),
                              PopupMenuItem(value: 9600, child: Text('9600')),
                              PopupMenuItem(value: 19200, child: Text('19200')),
                              PopupMenuItem(value: 38400, child: Text('38400')),
                              PopupMenuItem(
                                  value: 115200, child: Text('115200')),
                            ]),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(children: [
                        Text('Server Socket Port number:',
                            style: Theme.of(context).textTheme.title.merge(
                                isSocket
                                    ? null
                                    : const TextStyle(color: Colors.grey))),
                        SizedBox(width: 16),
                        Expanded(
                            child: TextField(
                                keyboardType: TextInputType.number,
                                enabled: isSocket,
                                autocorrect: false,
                                controller: _socketPortController)),
                      ]),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(children: [
                        Text('Security string:',
                            style: Theme.of(context).textTheme.title.merge(
                                isSocket
                                    ? null
                                    : const TextStyle(color: Colors.grey))),
                        SizedBox(width: 16),
                        Expanded(
                            child: TextField(
                                enabled: isSocket,
                                autocorrect: false,
                                controller: _securityStringController)),
                      ]),
                    ),
                    PopupMenuButton<bool>(
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 16.0),
                          title: Text(
                              'Meter incoming data by timestamp: ${settings.meterData}',
                              style: Theme.of(context).textTheme.title.merge(
                                  isSerial || isSocket
                                      ? null
                                      : const TextStyle(color: Colors.grey))),
                        ),
                        onSelected: (v) => settings.meterData = v,
                        enabled: isSerial || isSocket,
                        itemBuilder: (context) => const [
                              PopupMenuItem(value: true, child: Text('true')),
                              PopupMenuItem(value: false, child: Text('false'))
                            ]),
                  ]))),
    );
  }

  List<PopupMenuEntry<int>> _buildSerialPortMenu(BuildContext context) {
    final result = List<PopupMenuEntry<int>>();
    if (widget.devices.isEmpty) {
      result.add(
          PopupMenuItem(value: 0, child: Text('No Serial Devices Detected')));
    }
    for (int i = 1; i <= widget.devices.length; i++) {
      result.add(PopupMenuItem(
          value: i,
          child: Text('${i}:  Device ID ${widget.devices[i - 1].deviceId}')));
    }
    return result;
  }

  @override
  void settingsChanged() {
    setState(() {});
  }
}
