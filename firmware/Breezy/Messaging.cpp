#include <Arduino.h>
#include "Configuration.h"
#include "Messaging.h"
#include "Statistics.h"
#include "crc16.h"

CRC16 Crc16; //class instance for CRC
Messaging messaging;

uint8_t Messaging::poll(void)
{
  static uint32_t last_poll = 0;

  
  uint32_t mil = millis();
  
  if(mil - last_poll < (uint32_t)MESSAGE_PERIOD_MS){ // it is not the time yet
    return 0;
  }
  
  last_poll += (uint32_t)MESSAGE_PERIOD_MS;

  
  
  print_msg();
  print_service_msg();
  
  return 1;
  
}


uint8_t Messaging::print_msg(void)
{
  uint16_t time = (uint16_t)millis();

  char msg[200];
  sprintf(msg, "breezy,1,%5u,", time );
  
  dtostrf(statistics.p_act, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(statistics.slm, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(statistics.slm_sum, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(statistics.p_peak, 5, 1, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(statistics.p_mean, 2, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(statistics.peep, 2, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(statistics.rr, 2, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(statistics.o2_perc, 3, 0, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  dtostrf(statistics.ti, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");

  if(statistics.i_e > 1){
    dtostrf(statistics.i_e, 0, 1, &msg[strlen(msg)]);
    sprintf(&msg[strlen(msg)], ":1" );
  }else{
    sprintf(&msg[strlen(msg)], "1:" );
    dtostrf(1.0 / statistics.i_e, 0, 1, &msg[strlen(msg)]);
  }
  strcat(msg, ",");

  dtostrf(statistics.mvi, 4, 1, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(statistics.mve, 4, 1, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(statistics.vti, 3, 0, &msg[strlen(msg)]);
  strcat(msg, ",");

  dtostrf(statistics.vte, 3, 0, &msg[strlen(msg)]);
  strcat(msg, ",");

  uint16_t crc = Crc16.get_crc16(msg);

  sprintf(&msg[strlen(msg)], "%5u\r\n", crc);
  if ( xSemaphoreTake( xSerialSemaphore, ( TickType_t ) 5 ) == pdTRUE )
  {
    Serial.print(msg);
    xSemaphoreGive( xSerialSemaphore ); // Now free or "Give" the Serial Port for others.
  }
  
  return 0;
}

uint8_t Messaging::print_service_msg(void)
{
  uint16_t time = (uint16_t)millis();

  char msg[200];
  sprintf(msg, "service,1,%5u,", time );
  
  dtostrf(statistics.p_o2, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");

  sprintf(&msg[strlen(msg)], "%u,", statistics.is_i);  

  uint16_t crc = Crc16.get_crc16(msg);

  sprintf(&msg[strlen(msg)], "%5u\r\n", crc);  
  if ( xSemaphoreTake( xSerialSemaphore, ( TickType_t ) 5 ) == pdTRUE )
  {
    Serial.print(msg);
    xSemaphoreGive( xSerialSemaphore ); // Now free or "Give" the Serial Port for others.
  }
  return 0;
}
