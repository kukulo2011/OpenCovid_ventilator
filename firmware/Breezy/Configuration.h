
// Message time granularity
#define MESSAGE_PERIOD_MS (50)

// Statistics time granularity
#define STATISTICS_PERIOD_MS (50)

// Flow higher than this will switch to the inspiration state
// lower than negative will swith to the expiration state
// unit: lpm
#define INSPIRATION_FLOW_DETECT_TRIGGER (4.5)

// Minimum times - helps to debounce inspiration / expiration detection
#define MIN_INSPIRATION_TIME_MS 400
#define MIN_EXPIRATION_TIME_MS 600

// maximum value ADC on used MCU
#define ADC_MAXVAL (1023)
#define ADC_REF_VOLT (5)

// define which analog input is used to measure the actual pressure (default:  MPX5010 10 kPa)
#define P_ACT_PIN A9
#define P_ACT_MINVOLT (0.2)
#define P_ACT_MAXVOLT (4.7)
#define P_ACT_MINOUTP (0)
#define P_ACT_MAXOUTP (101.978) // cm H2O

// Oxygen supply sensor settings (default:  MPX5700AP 15 - 700 kPa)
#define P_O2_PIN A5
#define P_O2_MINVOLT (0.2)
#define P_O2_MAXVOLT (4.7)
#define P_O2_MINOUTP (10)
#define P_O2_MAXOUTP (700) // kPa
