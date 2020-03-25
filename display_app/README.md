# Breezy Ventilator Display
Display program for the Breezy emergency ventilator.

The main program in this directory is an Android/Flutter application that
gathers data from the ventilator, and displays it in graphical and numeric
form.  Control of the ventilator is not envisaged, because interacting with
a capacitive screen while wearing gloves is impractical.

This code is offered under the [MIT License](LICENSE), which allows it to
be used freely, but includes a strong liability disclaimer.

## Installation of a Debug Build

This application uses Flutter, which has a significant native (non-Java)
component.  Instead of an APK, applications are distributed as an "aab" file.
A tool called "bundletool" is used to generate apks, and then used again
to select the correct apk for a connected device.  So to install a debug
build, the first step is to go over to https://github.com/google/bundletool/,
and get the latest release of the bundletool jar.  As of this writing, that's
`bundletool-all-0.13.3.jar`.  Then, make up a little shell script or whatever to run
it.  Personally, I put the jar in `~/lib`, and I made a shell script like this in my
`~/bin`:
```bash
#!/bin/bash
JAR=$HOME/lib/bundletool-all-0.13.3.jar
echo "Running $JAR"
echo "cf. https://github.com/google/bundletool/"
java -jar $JAR "$@"
```
On my side, I'll build `appi-release.abb` with the command `flutter build appbundle`, and I'll
generate the (huge) `.apks` file, which I'll call `breezy.apks`.  (Note to self:  that's done with
`bundletool build-apks --bundle=app-release.aab --output=breezy.apks`).  I have to do this step, because
it signs the underlying apk files with a debug key.  To install the app, download `breezy.apks`,
and do this:
```ignorelang
bundletool install-apks --apks=~/tmp/tmp/breezy.apks
```
If there are  multiple devices connected, it will tell you to use `--device-id`.  Once you've
installed the app, and presumably switched the serial cable to the device under test, you
should be able to run it.  The power button in the upper-right hand corner of the display
screen does an `exit(0)` system call, which kills the process and should clean everything up.
