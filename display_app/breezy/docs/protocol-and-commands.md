# Data Protocol and Commands

The protocol for communicating from the embedded device to the
Breezy-Display app is fairly simple, and text based.  It consists of
individual lines of text, which can either be a command, or a set
of data values.  The set of commands varies slightly by input method.

## Input Sources

### USB Serial Input

Breezy-Display can accept input over the USB serial port.  Note that not
all Android devices support this mode.  To communicate this way, you need
to use an "OTG" cable under certain circumstances.  Before trying with
Breezy, it might be a good idea to test basic connectivity first with an
app like [Serial USB Terminal](https://play.google.com/store/apps/details?id=de.kai_morich.serial_usb_terminal).

Some random notes about my failed attempt to test serial connectivity from
Linux are shown in [my log file](../../billf_log.txt). 

### Bluetooth/RFCOMM

The Android version of the app can also accept input using the Bluetooth "Classic" RFCOMM protocol.
This is not to be confused with the newer Bluetooth LE, which is not currently implemented.  The
flutter library being used is not implemented for iOS, and from a brief search, it appears that
RFCOMM on iOS might be problematic.  There are Bluetooth LE libraries available, but there doesn't
seem to be a well-established Bluetooth LE standard for streaming data.  Still, Bluetooth LE could
be implemented, if there's a need - if you need this, drop me a line!  Bluetooth LE is supported by
a Flutter library that targets both iOS and Android.

Some random notes about successfully testing Bluetooth/RFCOMM connectivity between Linux and
an Android device are in [my log file](../../billf_log.txt).

### URL / Outgoing Socket

Breezy-Display can connect to an outgoing socket with an HTTP URL.  It reads the data from
the socket until the server closes the connection (or the user exits the data display screen).
This mode is great for demos and testing.  At present, you do need to type in the URL.

### Server Socket / Incoming Socket

Breezy-Display can listen on a port, and accept incoming socket connections.  This is great for
debugging - you can connect with `telnet` or `netcat`, and debug your screen layout and data protcol.
To add a bit of security, the first line sent to the app must be a security string.  The string is set
in the app's settings, and can not be blank.  It defaults to a UUID.

### Other Data Sources

You'll note two other data sources on the menu.  One pulls data from a captured log file, and is intended
to produce a quick demo.  The other generates data for display, as a way of testing a screen layout with
extreme data.

## Commands

The device can send various commands to the app.  The set of commands varies with
the source of the connection.  Many only apply to incoming connections to the server
socket ("ss" in the table), since this is a handy way to debug.

| Command | Availability | Function |
|:--------|:-------------|----------|
| `read-config` | all | The app receives a new JSON configuration.  The JSON may be split across multiple lines, and is terminated by a blank line.  The JSON format is given in [the configuration document](configure.md).|
| `read-config-compact:` | all | The app receives a new JSON configuration, sent as a base64-encoded gzip.  The command is followed by a checksum (after the colon), as a hex-encoded CRC32 value calculated over the binary gzipped value.  See `write-config-compact`.  With this command, a device can automatically configure Breezy-Display. |
| <a name="meter">`meter-data`</a> | all | Causes Breezy to insert delays between data samples.  This shouldn't be done if a device is supplying data in real time, but it can be useful for sending a captured log or other file to the app. |
| `reset-time` | all | Resets the app's notion of the current time.  This will cause the next data sample to be considered as arriving a short time after the last sample, regardless of its time value.  This is useful when replaying a log file in a loop.  The time gap between the two samples is about 40ms. |
| `next-url:` | url | Sets the next URL that will be opened when the current socket is closed by the server.  If unset, the app will stop displaying data when the connection closes. |
| `write-config` | ss | Writes out the current app configuration to the socket. |
| `write-config-compact` | ss |  Writes out a compact (base64 gzipped) version |
| `debug` | ss | Turns on "debug" mode.  This can help when debugging JSON errors with `read-config`. |
| `exit` | ss | close the current socket, and listen for a new connection |
| `help` | ss | Displays a help message with available commands |

## <a name="protocol">Data Protocol</a>

An incoming line will be discarded if the first character is "#".  Otherwise, 
it should be a __data sample__ that consists of
a number of fields, separated by commas, as follows:

| field | notes |
|:----|----|
| protocol-name | Name of the data protocol.  Set in configuration. |
| protocol-version | Version number of the protocol.  Set in configuration.  |
| time | Unsigned integer time value.  This is multiplied by a value set in the configuration to derive seconds.  It may wrap; the wrapping modulus is set in the configuration. |  
| data\* | zero or more data values, as set by the configuration. |
| screen? | If `switchScreenCommand` is true in the command, this gives the name of the screen that should be shown.  This allows a device to control which screen is showing, perhaps on a periodic basis. |
| checksum | An integer CRC-16 checksum value.  The value -1 is considered valid if `checksumIsOptional` is true in the configuration. |

The checksum is calculated over the ASCII character values starting
at the first character of `protocol_name` and ending with the comma
before `checksum`. That final comma _is_ included in the checksum
calculation.  The CRC algorithm is CRC-16-CCITT, as specified
by [The CRC Wikipedia Page](https://en.wikipedia.org/wiki/Cyclic_redundancy_check).  Sample C code to calculate this can be found at
http://srecord.sourceforge.net/crc16-ccitt.html.

Data fields may be double (floating-point) numbers, or may be strings.  If strings, the
follwing special escape sequences are recognized:

* "`\\`" is converted to "`\`"
* "`\c`" is converted to "`,`" (a comma)
* "`\n`" is converted to a newline character

Double values may be formatted in a variety of ways, according to the configuration.
