
#ifndef SENSORS_H 
#define SENSORS_H

#include "SFM3300.h"

class Sensors{
  public:
  float p_act; // actual pressure (cmH2O)
  float p_o2; // O2 supply pressure 
  float slm; // flow (l/min)
  float o2_perc; // O2 concentration

  void init(void);
  uint8_t measure(void);

  private:
  float AnalogSensor(float MinVolt, float MaxVolt, float MinOutp, float MaxOutp, const uint8_t pin);
  
};

extern Sensors sensors;
extern SFM3300 sfm;

#endif // #ifndef SENSORS_H 
