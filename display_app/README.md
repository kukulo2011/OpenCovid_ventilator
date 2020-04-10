# Breezy Ventilator Display
Display program for the Breezy emergency ventilator.

The main program in this directory is an Android/Flutter application that
gathers data from the ventilator, and displays it in graphical and numeric
form.  Control of the ventilator is not envisaged, because interacting with
a capacitive screen while wearing gloves is impractical.

This code is offered under the [MIT License](LICENSE), which allows it to
be used freely, but includes a strong liability disclaimer.

Once you've
installed the app, and presumably switched the serial cable to the device under test, you
should be able to run it.  The power button in the upper-right hand corner of the display
screen does an `exit(0)` system call, which kills the process and should clean everything up.

## Platforrms

This application targets all Android platforms on which Flutter is supported.
As of this writing, all of the libraries support iOS as well, so it should work
on iPhone, but this has not been tested.  Flutter is available on Android devices
"armeabi-v7a (ARM 32-bit), arm64-v8a (ARM 64-bit), and x86-64 (x86 64-bit)."  Alas,
"Flutter does not currently support building for x86 Android." - see 
https://flutter.dev/docs/deployment/android#what-are-the-supported-target-architectures.

## Building

Development is being done on Android Studio.  That's a big download and a lot of
installation, though.  It should be possible to deploy and run if you have the
Android SDK, and the [Flutter SDK](https://flutter.dev/docs/development/tools/sdk/releases).
If there are problems, `flutter doctor` might be helpful.  If everything works, it should
look like this:
![Running from Command Line](misc/flutter_run.png)

### Commands used to build/deploy
```
flutter clean
flutter build appbundle
```
This makes a build for the Play Store.  Alternately,
```
flutter clean
flutter build apk --split-per-abi
```
makes APKs suitable for github

## Testing with a socket

The application is designed to connect to an embedded system using
a serial connection over USB.  In the future, it will be extended
for Bluetooth connections.  It also allows a data source to connect
a socket to the display device, which may be useful for debugging.
See [`misc/send_data_to_display.sh`](misc/send_data_to_display.sh) for a Linux script to
send a log file to the display device.
