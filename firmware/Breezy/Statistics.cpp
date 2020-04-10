#include <Arduino.h>
#include "Configuration.h"
#include "Statistics.h"
#include "Sensors.h"

Statistics statistics;

void Statistics::init(void)
{
  sensors.init();

  vti_int = 0; // vti integrator
  vte_int = 0; // vte integrator
  uint32_t last_insp_started_ms = 0;
  uint32_t last_exp_started_ms = 0;
  slm_sum = 0;
  p_mean_detect = 0;
  p_mean_count = 0;
}

uint8_t Statistics::is_inspiration(void)
{
  uint32_t mil = millis();
  static uint8_t insp = 0;
  if((slm > (float)INSPIRATION_FLOW_DETECT_TRIGGER) && (mil - last_exp_started_ms > MIN_EXPIRATION_TIME_MS)){
    insp = 1;
  }else if((slm < -((float)INSPIRATION_FLOW_DETECT_TRIGGER))  && (mil - last_insp_started_ms > MIN_INSPIRATION_TIME_MS)){
    insp = 0;
  } 
  return insp;
}

uint8_t Statistics::poll(void)
{
  static uint32_t last_poll = 0;
  static uint8_t last_is_insp = 0;
  uint8_t is_insp = 0;
  uint32_t mil = millis();

  
  if(mil - last_poll < (uint32_t)STATISTICS_PERIOD_MS){ // it is not the time yet
    return 0;
  }
  
  last_poll += (uint32_t)STATISTICS_PERIOD_MS;

  
  sensors.measure();
  
  p_act = sensors.p_act; // actual pressure (cmH2O)
  slm = sensors.slm; // flow (l/min)
  float dv_ml_s = slm * 1000 / 60; // actual flow in milliliters per second 
  float dv_ml = dv_ml_s * ((float)STATISTICS_PERIOD_MS) / 1000; // volume per measurement period
  
  if(p_act > p_peak_detect) p_peak_detect = p_act; // detect peak pressure
  p_mean_detect += p_act; // calculate mean pressure
  p_mean_count++;
  
  /*
  Volume integration
  dt = STATISTICS_PERIOD_MS (ms)
  slm = standard liters per minute (spm) 
  */
  
  is_insp = is_i = is_inspiration();
  if(is_insp){ // inspiration
    if(!last_is_insp){ // inspiration just started!
      vte = abs(vte_int);
      vte_int = 0; // reset expiration volume integrator
      te = (float)(mil - last_exp_started_ms)/1000; // calculate expiration time
      last_insp_started_ms = mil; 
      rr = 60 / (te + ti); // calculate respiratory rate (breaths/min)
      mve = rr * vte / 1000; // calculate mean volume expiration (l/min)
      i_e = ti/te; // calculate inspiraton : exspiration
      
      slm_sum = 0; /* TODO: At the beginning of inspiration we assume empty volume. 
      This is to prevent driftng off the volume chart because of integration of error. Is this correct?
      */
      p_peak = p_peak_detect;
      p_peak_detect = 0;
      p_mean = p_mean_detect / p_mean_count; // calculate mean pressure
      p_mean_detect = 0;
      p_mean_count = 0;
      peep = peep_detect;
    }
  
    vti_int += dv_ml;// integrate inspiration volume
    slm_sum += dv_ml;// integrate volume
  
  }else{ // expiration
    if(last_is_insp){ // expiration just started!
      vti = abs(vti_int);
      vti_int = 0; // reset inspiration volume integrator
      ti = (float)(mil - last_insp_started_ms)/1000; // calculate expiration time
      last_exp_started_ms = mil; 
      rr = 60 / (te + ti); // calculate respiratory rate (breaths/min)
      mvi = rr * vti / 1000; // calculate mean volume inspiration (l/min)
      i_e = ti/te; // calculate inspiraton : exspiration
    }
  
    vte_int += dv_ml; // integrate expiration volume
    slm_sum += dv_ml;// integrate volume
    
    peep_detect = p_act; // TODO is this enough to detect peep?
  
  }
  
  last_is_insp = is_insp;
  
  float slm_sum; // volume (ml)
  
  
  
  return 1;
  
}
