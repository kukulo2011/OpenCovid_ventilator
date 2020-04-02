#include <Arduino.h>
#include "SFM3300.h"
#include "I2C.h"
#include "Statistics.h"
#include "Messaging.h" 


void setup() {
  
  Serial.begin(115200);  // start serial for output

  Serial.println("MCU_RESET");

  statistics.init();
}

void loop() {

  statistics.poll();
  messaging.poll();
  
  
  messaging.print_msg();
  messaging.print_service_msg();
  
  delay(50);
}
