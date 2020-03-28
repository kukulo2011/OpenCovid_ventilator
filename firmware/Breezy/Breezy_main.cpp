#include <Arduino.h>
#include "SFM3300.h"
#include "I2C.h"
#include "Sensors.h"
#include "crc16.h" 

Sensors sensors;

void setup() {
  
  Serial.begin(9600);  // start serial for output

  Serial.println("MCU_RESET");

  sensors.init();
}

void loop() {

  sensors.measure();
  sensors.print_msg();
  
  delay(50);
}
