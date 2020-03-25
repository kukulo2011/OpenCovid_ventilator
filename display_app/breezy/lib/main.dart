import 'package:flutter/material.dart';
import 'dart:io' show exit;
import 'serial.dart';

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

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Breezy Prototype',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: BreezyHomePage(title: 'Breezy Home Page'),
    );
  }
}

class BreezyHomePage extends StatelessWidget {
  final String _title;

  BreezyHomePage({Key key, String title})
    : this._title = title, super(key: key);

  @override
  Widget build(BuildContext context) {
    const bigTextStyle = TextStyle(fontSize: 20);
    return Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.power_settings_new),
              tooltip: 'Quit',
              onPressed: () { exit(0); }
            )],
    ),
    body: Center(
            child: Column(children: <Widget>[
          const SizedBox(height: 50),
          RaisedButton(
              child: const Text('Test Serial Connection', style: bigTextStyle),
              onPressed: () {
                Navigator.push<void>(context,
                    MaterialPageRoute(builder: (context) => SerialTestPage()));
              }),
          const SizedBox(height: 30),
          Builder(
              builder: (BuildContext context) => RaisedButton(
                  child: const Text('Show Fake Graphs', style: bigTextStyle),
                  onPressed: () {
                    Scaffold.of(context)
                        .showSnackBar(SnackBar(content: Text('TODO')));
                  }))
        ])));
  }
}
