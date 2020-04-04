#ifndef SFM3300_H
#define SFM3300_H


#include <inttypes.h>

class SFM3300 {
  public: 
    float slm;
    float slm_sum;

    uint8_t init();
    uint8_t measure();

    private:
    long int slm_sum_raw;
};

#endif // #ifndef SFM3300_H
