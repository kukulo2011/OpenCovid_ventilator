#ifndef STATISTICS_H
#define STATISTICS_H



class Statistics{
  public:
  float p_act; // actual pressure (cmH2O)
  float slm; // flow (l/min)
  float slm_sum; // volume (ml)
  float p_peak; // peak pressure (cmH2O)
  float p_mean; // mean pressure (cmH2O)
  float peep; // positive end-expiratory pressure (cmH2O)
  float rr; // respiratory rate
  float o2_perc; // O2 concentration
  float ti; // inspiration time (s)
  float te; // expiration time (s) // not printed in message
  float i_e; // inspiraton : exspiration
  float mvi; // mean volume inspiration (l/min)
  float mve; // mean volume expiration (l/min)
  float vti; // volume tidal inspiration (ml)
  float vte; // volume tidal expiration (ml)

  float p_o2; // O2 supply pressure

  uint8_t is_i; // is inspiration - debug
  
  uint8_t poll(void);
  void init(void);

  private:
  uint8_t is_inspiration(void); // returns 0 = inspiration, 1 = expiration
  float vti_int; // mvi integrator
  float vte_int; // mvi integrator
  uint32_t last_insp_started_ms;
  uint32_t last_exp_started_ms;
  float p_peak_detect;
  float p_mean_detect;
  uint16_t p_mean_count;
  float peep_detect;
};

extern Statistics statistics;

#endif // #ifndef STATISTICS_H
