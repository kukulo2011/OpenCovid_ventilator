# Configuration File

The application can be configured by sending it a configuation file.
The app stores these files, and the user can select between them
in the settings menu.  The commands for sending a file are documented
in the 
[protocol and commands document](protocol-and-commands.md).  You can see
examples with comments at the app's website:
*  [Minimal Example](https://breezy-display.jovial.com/minimal_configuration.breezy) - or [on Github](https://github.com/zathras/breezy-display/blob/master/docs/minimal_configuration.breezy)
*  [Weather Demo](https://breezy-display.jovial.com/weather_demo.breezy) - or [on Github](https://github.com/zathras/breezy-display/blob/master/docs/weather_demo.breezy)

The structure of the JSON file is given in the following diagram.  Note
that the [implementation classes](../lib/configure.dart) have a similar
structure, but with slight changes for runtime efficiency.  For example,
at runtime `DataFeed`'s `values` list is stored in two lists, one for values 
that appear in time charts, and another for values that are shown numercally.
The below diagram represents the JSON format.

![JSON format UML Diagram](configure.svg)

## `BreezyConfiguration`

The JSON document is an instance of `BreezyConfiguration`.  The `version` 
number is fixed at 1, and is just there to offer some future-proofing, in the
(unlikely) event of a major restructuring.  The `name` gives the name as
presented to the user, and also gives the file name for storage on the device.
`sampleLog` may be empty; it is a list of data feed entries for the
"Demo Log Data" option.  It contains a single `feed` and a list of
`screens`.

## `DataFeed`

The feed has a `protocolName` and `protocolVersion` that are matched against
the first two values of each [data sample](protocol-and-commands.md#protocol).
`ticksPerSecond` determines how many integral `time` values make up one
second of wall clock time; this is used to calibrate the X axis, and is
used for timing when data is [metered](protocol-and-commands.md#meter).
The `timeModulus` determines when the feed's `time` value wraps.  For example,
if the device uses 16 bit unsigned ints for `time`, `timeModulus` should be
set to 65536.  A value of `null` is used if the value doesn't wrap; note that
Breezy-Display uses Dart's 64 bit signed integers, so there's no need to wrap
if the device doesn't need to.  `checksumIsOptional` determines if a 
`checksum` value in the feed of -1 is accepted.  This is useful for testing,
or if you're using a reliable transport (like sockets) to connect to the 
device, and you don't want to bother with a checksum.

`screenSwitchCommand` is a little complicated.  A configuration can have
multiple screens, and each `Screen` has a name.  If `screenSwitchCommand`
is enabled, each data sample has an extra value, just before the `checksum`.
This value gives the name of the current screen; it instructs the app to
switch to that screen if it isn't already showing.  Note that it doesn't make
sense to have a `ScreenSwitchArrow` in the UI if `screenSwitchCommand` is
enabled.

A data feed contains a list of values that define the payload of a
[data sample](protocol-and-commands.md#protocol).

### `Value`

A value has a `demoMinValue` and a `demoMaxValue` - these are just used
for the "Screen Debug Functions" data source.  A `FormattedValue` adds
a format string.  This is used to format a double value if 
`keepOriginalFormat` is false, and in any case is used to format the random
values for the screen debug functions.  A `RatioValue` is a value that is
displayed as "n:1" if the value is >= 1, or "1:n" otherwise; n is 
always >= 1.  If a RatioValue's `keepOriginalFormat` is true, the data sample
should be a string that contains "1:" or ":1".

Each value has a list of zero or more `displayers`.  A values displayers
are part of the value, largely because they're somewhat complex structures
that are typically reused across the portrait and landscape layouts.  They
can be reused across screens as well.

#### `DataDisplayer`


##### `TimeChart`

##### `ValueBox`

### `Screen`

#### `ScreenWidget`

##### `ScreenColumn`

##### `ScreenRow`

##### `Spacer`

##### `Border`

##### `Label`

##### `ScreenSwitchArrow`

##### `DataWidget`
