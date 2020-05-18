
#ifndef SENSORS_H 
#define SENSORS_H

#include "SFM3300.h"

class Sensors{
  public:
  
  // sensor measurements
  float p_act; // actual pressure (cmH2O)
  float p_o2; // O2 supply pressure (kPa)
  float slm; // flow (l/min)
  float o2_perc; // O2 concentration

  // potentiometer settings
  float set_o2; // O2 concentration (21 to 100) %
  float set_max_p; // Max. Pressure (10 to 40) cmH2O
  float set_peep; // PEEP pressure (5 to 20) cmH2O
  float set_rr; // respiratory rate (12 to 20) / min
  float set_tv; // Tidal volume (200 - 1000) ml 
  float set_ie; // Inspiration : Expiration, 

  void init(void);
  uint8_t measure(void);

  private:
  float AnalogSensor(float MinVolt, float MaxVolt, float MinOutp, float MaxOutp, const uint8_t pin);
  
};

extern Sensors sensors;
extern SFM3300 sfm;

#endif // #ifndef SENSORS_H 
