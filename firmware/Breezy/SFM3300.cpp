
#include <Arduino.h>
#include "I2C.h"
#include "SFM3300.h"

// SFM3300's GND pin connects to D19. By bringing it to HIGH, we turn off power to the sensor.
// The sensor cannot leak current from I2C, since I2C has PULLUPS. We need to reset I2C interface too
// to ensure the I2C pins are not active low ?
#define SFM3300_POWER_INIT() pinMode(19, OUTPUT)
#define SFM3300_POWER_ON() digitalWrite(19, LOW)
#define SFM3300_POWER_OFF() digitalWrite(19, HIGH)


uint8_t SFM3300::init()
{
  SFM3300_POWER_INIT();
  SFM3300_POWER_OFF();
  delay(100);
  SFM3300_POWER_ON();
  delay(110);

  // TODO try to remove delays.. In real application it is not acceptable!

  slm_sum_raw = 0;
  slm_sum = 0;
  uint8_t ret = 0;

  ret = I2c.write(64, 0x10, 0); // address
  
  return ret;
}

uint8_t SFM3300::measure()
{
  uint16_t f_raw = 0;
  uint8_t ret = 0;
  uint8_t data[3];
  ret = I2c.read(64, 3, data);
  if(ret == 0){
    f_raw = (data[0] << 8);
    f_raw |= data[1];
    uint8_t crc = data[2]; // TODO check CRC
    slm = (((float)f_raw) - 32768)/120;
    slm_sum_raw += ((long int)f_raw)-32768;
    slm_sum = slm_sum_raw / 120;
    slm_sum = slm_sum*1000/60/50;
  }
  return ret;
}
