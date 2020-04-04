/*
Testing sketch for Breezy app for Arduino Nano
*/

#include "crc16.h"

  float p_act=35; // actual pressure (cmH2O)
  float slm=65; // flow (l/min)
  float slm_sum=250; // volume (ml)
  float p_peak=50; // peak pressure (cmH2O)
  float p_mean=35; // mean pressure (cmH2O)
  float peep=65; // positive end-expiratory pressure
  float rr=85; // respiratory rate
  float o2_perc=35; // O2 concentration
  float ti=25; // inspiration time (s)
  float te=20; // expiration time (s) // not printed in message
  float i_e=0.7; // inspiraton : exspiration
  float mvi=12; // mean volume inspiration (l/min)
  float mve=11.8; // mean volume expiration (l/min)
  float vti=468; // volume tidal inspiration (ml)
  float vte=457; // volume tidal expiration (ml)

  float p_o2; // O2 supply pressure

  CRC16 Crc16;
 
void setup() {
  Serial.begin(115200);
  Serial.println("Breezy app testing sketch");

}
void loop() {
 
 uint16_t time = (uint16_t)millis();

    char msg[200];
  sprintf(msg, "breezy,1,%5u,", time );
  
  dtostrf(p_act, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  p_act=p_act+15*sin(random(0,6.28));

  if (p_act>=50) p_act=25;
  if (p_act<=0) p_act=25;
  
  dtostrf(slm, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");
  
  slm=slm+1;
  
  if (slm==101) slm=-100;
  
  dtostrf(slm_sum, 5, 2, &msg[strlen(msg)]);
  strcat(msg, ",");
  
   slm_sum=slm_sum+10*cos(random(0,6.28));
  
  if (slm_sum>=800) slm_sum=230;
  if (slm_sum<=0) slm_sum=250;

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
  
  delay(50);
    
}
