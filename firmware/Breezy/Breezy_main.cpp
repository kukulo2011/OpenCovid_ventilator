#include <Arduino.h>
#include "SFM3300.h"
#include "I2C.h"
#include "Statistics.h"
#include "Messaging.h" 
#include "Display.h"


void setup() {
  
  Serial.begin(115200);  // start serial for output

  Serial.println("MCU_RESET");

  statistics.init();

  display.init();
}

void loop() {

  statistics.poll();
  messaging.poll();
  display.poll();
  
  
  delay(50);
}
