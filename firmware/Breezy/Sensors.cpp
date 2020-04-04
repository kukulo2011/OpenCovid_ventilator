
#include <Arduino.h>
#include "Configuration.h"
#include "I2C.h"
#include "SFM3300.h"
#include "Sensors.h"


SFM3300 sfm; //class instance for flow sensor

Sensors sensors;

void Sensors::init(void)
{
  I2c.begin();
  sfm.init();  
}

uint8_t Sensors::measure(void)
{
  uint8_t ret = 0;
  if(0 == sfm.measure()){
    slm = sfm.slm;
  }else{
    sfm.init();
    slm = NAN;
    ret++; // indicate error
  }

  p_act = AnalogSensor((float)P_ACT_MINVOLT, (float)P_ACT_MAXVOLT, (float)P_ACT_MINOUTP, (float)P_ACT_MAXOUTP, P_ACT_PIN);
  p_o2 = AnalogSensor((float)P_O2_MINVOLT, (float)P_O2_MAXVOLT, (float)P_O2_MINOUTP, (float)P_O2_MAXOUTP, P_O2_PIN);
  
  return ret;
}

float Sensors::AnalogSensor(float MinVolt, float MaxVolt, float MinOutp, float MaxOutp, const uint8_t pin)
{
  float adc_volt = ((float)analogRead(pin))/((float)ADC_MAXVAL)*((float)ADC_REF_VOLT);
  return (adc_volt - MinVolt) * (MaxOutp - MinOutp)/(MaxVolt - MinVolt);
}
