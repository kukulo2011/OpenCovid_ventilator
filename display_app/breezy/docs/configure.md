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

`ticksPerSecond`
