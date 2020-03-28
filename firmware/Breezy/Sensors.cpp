
#include <Arduino.h>
#include "I2C.h"
#include "SFM3300.h"
#include "Sensors.h"
#include "crc16.h"

SFM3300 sfm; //class instance for flow sensor
CRC16 Crc16; //class instance for CRC

void Sensors::init(void)
{
  I2c.begin();
  sfm.init();  
  Serial.println("Sensors init");
  
}

uint8_t Sensors::measure(void)
{
  uint8_t ret = 0;
  if(0 == sfm.measure()){
    slm = sfm.slm;
    slm_sum = sfm.slm_sum;
  }else{
    sfm.init();
    slm = NAN;
    slm_sum = NAN;
    ret++; // indicate error
  }

  


  return ret;
}

uint8_t Sensors::print_msg(void)
{
  uint16_t time = (uint16_t)millis();

  char msg[200];
  sprintf(msg, "breezy,1,%5u,", time );
  
  dtostrf(p_act, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(slm, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(slm_sum, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(p_peak, 5, 1, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(p_mean, 2, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(peep, 2, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(rr, 2, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(o2_perc, 3, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(ti, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(i_e, 4, 1, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(mvi, 4, 1, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(mve, 4, 1, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(vti, 3, 0, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(vte, 3, 0, &msg[strlen(msg)]);
  strcat(msg, ",");

  uint16_t crc = Crc16.get_crc16(msg);

  sprintf(&msg[strlen(msg)], "%5u\r\n", crc);  

  Serial.print(msg);
  /*
  Serial.print(slm);
  Serial.print(",");
  Serial.println(slm_sum);
*/

  return 0;
}
