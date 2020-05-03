## The Breezy ventilator concept

The pneumatic and mechanic schematic for the ventilator is not yet finished, but there is an idea. We plan to use a 7040 DC blower as air pressure source. We will add oxygen from pressurized input port. The oxygen flow will be controlled either using 2 solenoids to create doses, or 1 proportional solenoid and O2 flow sensor. The inspiration pressure will be controlled changing both air and O2 flow. There will be a 10 kPa range differential pressure sensor. The tidal volume will be controlled using 2 flow sensors - on the inspiration and expiration tube.

## Hardware

We plan using RAMPS 1.4 board along with Arduino Mega and the RepRapDiscount Full Graphic Smart Controller. The board has 3 power FET's that can be used to control the blower RPM and solenoid valves. The stepper drivers may be used to drive steppers in precision valves. 
The LCD will show basic quantities and enable setting some (not so often used) parameters.
To control the main ventilator parameteres, there wil be several potentiometers on the panel (TBD) allowing fast and easy control.
The on-line charts of pressure, flow and volume will be available via [Android app](../display_app).

## Installation
Use Arduino IDE. Open Breezy.ino to compile the code and flash the Arduino Mega. 
In Arduino IDE add the following libraries:
 * FreeRTOS by Richard Barry
 * U8glib

To use the app, connect the usb cable to your phone/tablet with the app installed.

### Sensors

There will be several sensors attached:
- SFM3300 D (flow sensor for breath) - already implemented. Connects to hardware i2c. This may be alternativaly exchanged by a differential pressure transducer BPS125  -  A  D  0P04 (250 Pa range), since the SFM3300 are short on supplies.
- MPX5010dp differential pressure sensor to measure pressure in the mixture inspired. Connects to analog in. 
- MPX5700AP absolute pressure up to 7 bar to measure O2 supply. (TBD - is it good for pure O2?)  Connects to analog in.

This is an early development stage. Stay tuned!
