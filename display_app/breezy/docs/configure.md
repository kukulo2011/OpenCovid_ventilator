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

Generally speaking, "optional" values must be specified, but they may be null.

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

Each value has a list of zero or more `displayers`.  A value's displayers
are part of the value, largely because they're somewhat complex structures
that are typically reused across the portrait and landscape layouts.  They
can be reused across screens as well.

#### `DataDisplayer`

A data displayer can be a `TimeChart` or a `ValueBox`.  It determines how
a value is displayed.  The `id` field is used identify the displayer in a
`DataWidget` that is part of a `Screen` that displays the value.

##### `TimeChart`

A time chart collects the values over the past `timeSpan` seconds, and displays them as a chart, with time as the X axis.  In a `rolling` chart, the values stay stationary, and the insert point rolls across the screen, with a gap of 5%
in the X axis. Otherwise, in a "sliding" chart, the most recent value is on the right, and the other values slide to the left over time.  `minValue` and `maxValue` determine the Y axis limits; out-of-range values are clamped, and displayed
in red.  `color` gives the color of the line and other UI elements; it is
given as an eight-digit hex ARGB value in a string.  An optional `label`
gives a name for the data, and `labelHeightFactor` determines what percent
of the available vertical space is reserved for the label.

##### `ValueBox`

A value box displays the value of the data directly, either as a number
or a string.  `color`, `label` and `labelHeightFactor` behave the same
as for `TimeChart`.  The optional `units` gives a string displayed
below the value.  `prefix` and `postfix` give constant stringd displayed
before and after the value.

`format` isn't used to format the actual value; it's used to reserve
space for the value, by determining the font size.  When displayed, enough
space for the format string will be reserved, and in the case of
a `decimal` alignment, a decimal point  in the value will be lined up
consistently - or if there is no decimal point, the "units" part of the
value will be rendered in a consistent place.  The `align` value can be
either `left`, `center`, `decimal` or `right` - the space reserved for
a `decimal`-aligned value is centered in the renderable area.  If a value
overflows the space allocated according to the format string, it will simply
spill over the available area.

### `Screen`

A screen has a name, used in conjunction with `screenSwitchCommand`.  It
must have one layout, but will usually have both a `portrait` and a
`landscape` layout.

#### `ScreenWidget`

`ScreenWidget` is the abstract type representing all visual elements in a
screen.  Every `ScreenWidget` has a `flex` value that determines how
"flexible" it is when allocating space.  With the exception of `Border`,
flex must be a positive integer.  A widget that is more flexible takes up
more space - if the widget is in a column, it stretch more vertically in
proportion to its flex value; ditto for the width in a row.  Of course,
`flex` is meaningless if there is only one element in the given dimension,
as is the case for the row or column at the top of the `Screen` tree.

##### `ScreenColumn`

A column contains rows and other widgets, arranged in a column from top
to bottom.  It may not
contain another column, but the rows it contains may contain columns.
The `content` of a column is the set of widgets it contains.

##### `ScreenRow`

A row is like a column, except its `content` is arranged as a row,
left to right.  A row may not directly contain other rows.

##### `Spacer`

A spacer inserts blank space into a layout.

##### `Border`

A border is used to display a (usually thin) border line of the specified
color.  The width is in Flutter pixels.  Usually a Border will have a null
`flex` value, because you don't want the line's width to scale with the screen
size, but if you specify a `flex`, the `width` will be ignored and the
border will scale like any other widget.

##### `Label`

A label displays the given fixed text in the alloted space, using the
biggest font that will fit.

##### `ScreenSwitchArrow`

A screen swith arrow displays an arrow pointing to the right.  When touched
by the user, it causes the app to move to the next screen in the
configuration's `screens` list.

##### `DataWidget`

A `DataWidget` is a reference to one of the `displayers` of a value.  In
addition to the `flex`, it just contains the `displayerID`, which must match
the `id` value of one of the `DataDisplayer`s in the feed.
