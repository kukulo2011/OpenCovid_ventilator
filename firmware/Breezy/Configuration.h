#include <Arduino_FreeRTOS.h>
#include <semphr.h>  // add the FreeRTOS functions for Semaphores (or Flags).
extern SemaphoreHandle_t xSerialSemaphore;
extern SemaphoreHandle_t xStatisticsSemaphore;

// Message time granularity
#define MESSAGE_PERIOD_MS (50)

// Statistics time granularity
#define STATISTICS_PERIOD_MS (50)

// Display time granularity
#define DISPLAY_PERIOD_MS (700)

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

// LCD wiring (According to RAMPS and Reprap discount smart controller)
#define LCD_EN_PIN 23
#define LCD_RW_PIN 17
#define LCD_DI_PIN 16

// VALVES wiring
#define VALVE_A_PIN 4
#define VALVE_B_PIN 5
#define VALVE_C_PIN 6
#define VALVE_D_PIN 11

#define valve_A_close() digitalWrite(VALVE_A_PIN, LOW)
#define valve_B_close() digitalWrite(VALVE_B_PIN, LOW)
#define valve_C_close() digitalWrite(VALVE_C_PIN, HIGH)
#define valve_D_close() digitalWrite(VALVE_D_PIN, HIGH)

#define valve_A_open() digitalWrite(VALVE_A_PIN, HIGH)
#define valve_B_open() digitalWrite(VALVE_B_PIN, HIGH)
#define valve_C_open() digitalWrite(VALVE_C_PIN, LOW)
#define valve_D_open() digitalWrite(VALVE_D_PIN, LOW)



  
  
  
  
