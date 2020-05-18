
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

  // measure analog sensors
  p_act = AnalogSensor((float)P_ACT_MINVOLT, (float)P_ACT_MAXVOLT, (float)P_ACT_MINOUTP, (float)P_ACT_MAXOUTP, P_ACT_PIN);
  p_o2 = AnalogSensor((float)P_O2_MINVOLT, (float)P_O2_MAXVOLT, (float)P_O2_MINOUTP, (float)P_O2_MAXOUTP, P_O2_PIN);
  
  // measure potentiometers
  set_o2 = AnalogSensor((float)SET_O2_MINVOLT, (float)SET_O2_MAXVOLT, (float)SET_O2_MINOUTP, (float)SET_O2_MAXOUTP, SET_O2_PIN);
  set_max_p = AnalogSensor((float)SET_MAX_P_MINVOLT, (float)SET_MAX_P_MAXVOLT, (float)SET_MAX_P_MINOUTP, (float)SET_MAX_P_MAXOUTP, SET_MAX_P_PIN);
  set_peep = AnalogSensor((float)SET_PEEP_MINVOLT, (float)SET_PEEP_MAXVOLT, (float)SET_PEEP_MINOUTP, (float)SET_PEEP_MAXOUTP, SET_PEEP_PIN);
  set_rr = AnalogSensor((float)SET_RR_MINVOLT, (float)SET_RR_MAXVOLT, (float)SET_RR_MINOUTP, (float)SET_RR_MAXOUTP, SET_RR_PIN);
  set_tv = AnalogSensor((float)SET_TV_MINVOLT, (float)SET_TV_MAXVOLT, (float)SET_TV_MINOUTP, (float)SET_TV_MAXOUTP, SET_TV_PIN);
  set_ie = AnalogSensor((float)SET_IE_MINVOLT, (float)SET_IE_MAXVOLT, (float)SET_IE_MINOUTP, (float)SET_IE_MAXOUTP, SET_IE_PIN);
  
  return ret;
}

float Sensors::AnalogSensor(float MinVolt, float MaxVolt, float MinOutp, float MaxOutp, const uint8_t pin)
{
  float adc_volt = ((float)analogRead(pin))/((float)ADC_MAXVAL)*((float)ADC_REF_VOLT);
  return (adc_volt - MinVolt) * (MaxOutp - MinOutp)/(MaxVolt - MinVolt) + MinOutp;
}
