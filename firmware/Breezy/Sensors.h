

class Sensors{
  public:
  float p_act; // actual pressure (cmH2O)
  float slm; // flow (l/min)
  float slm_sum; // volume (ml)
  float p_peak; // peak pressure
  float p_mean; // mean pressure
  float peep; // positive end-expiratory pressure
  float rr; // respiratory rate
  float o2_perc; // O2 concentration
  float ti; // inspiration time (s)
  float i_e; // inspiraton : exspiration
  float mvi; // mean volume inspiration (l/min)
  float mve; // mean volume expiration (l/min)
  float vti; // volume tidal inspiration (ml)
  float vte; // volume tidal expiration (ml)
  
  uint8_t measure(void);
  uint8_t print_msg(void);
  void init(void);


  
};

extern Sensors sensors;
extern SFM3300 sfm;
