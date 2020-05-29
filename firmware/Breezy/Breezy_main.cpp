#include <Arduino.h>
#include <Arduino_FreeRTOS.h>
#include <semphr.h>  // add the FreeRTOS functions for Semaphores (or Flags).
#include "SFM3300.h"
#include "I2C.h"
#include "Statistics.h"
#include "Messaging.h" 
#include "Display.h"
#include "Configuration.h"

// Declare a mutex Semaphore Handle which we will use to manage the Serial Port.
// It will be used to ensure only only one Task is accessing this resource at any time.
SemaphoreHandle_t xSerialSemaphore;

SemaphoreHandle_t xStatisticsSemaphore;

void TaskLCD( void *pvParameters );
void TaskVentilator( void *pvParameters );
void TaskValve( void *pvParameters );

void setup() {

  pinMode(VALVE_A_PIN, OUTPUT);
  pinMode(VALVE_B_PIN, OUTPUT);
  pinMode(VALVE_C_PIN, OUTPUT);
  pinMode(VALVE_D_PIN, OUTPUT);

  valve_A_close();
  valve_B_close();
  valve_C_close();
  valve_D_close();
  
  Serial.begin(115200);  // start serial for output

  Serial.println("MCU_RESET");

  statistics.init();

  display.init();

  // Semaphores should only be used whilst the scheduler is running, but we can set it up here.
  if ( xSerialSemaphore == NULL )  // Check to confirm that the Serial Semaphore has not already been created.
  {
    xSerialSemaphore = xSemaphoreCreateMutex();  // Create a mutex semaphore we will use to manage the Serial Port
    if ( ( xSerialSemaphore ) != NULL )
      xSemaphoreGive( ( xSerialSemaphore ) );  // Make the Serial Port available for use, by "Giving" the Semaphore.
  }

  if ( xStatisticsSemaphore == NULL )  // Check to confirm that the Serial Semaphore has not already been created.
  {
    xStatisticsSemaphore = xSemaphoreCreateMutex();  // Create a mutex semaphore we will use to manage the Serial Port
    if ( ( xStatisticsSemaphore ) != NULL )
      xSemaphoreGive( ( xStatisticsSemaphore ) );  // Make the Serial Port available for use, by "Giving" the Semaphore.
  }
  
  // Now set up two Tasks to run independently.
  xTaskCreate(
    TaskLCD
    ,  "LCD"  // A name just for humans
    ,  1500  // This stack size can be checked & adjusted by reading the Stack Highwater
    ,  NULL
    ,  2  // Priority, with 3 (configMAX_PRIORITIES - 1) being the highest, and 0 being the lowest.
    ,  NULL );

  xTaskCreate(
    TaskVentilator
    ,  "Ventilator"
    ,  1500  // Stack size
    ,  NULL
    ,  2  // Priority
    ,  NULL );


  xTaskCreate(
    TaskValve
    ,  "Valve"
    ,  500  // Stack size
    ,  NULL
    ,  2  // Priority
    ,  NULL );

  // Now the Task scheduler, which takes over control of scheduling individual Tasks, is automatically started.
}

void loop() {

}

/*--------------------------------------------------*/
/*---------------------- Tasks ---------------------*/
/*--------------------------------------------------*/

void TaskLCD( void *pvParameters __attribute__((unused)) )  // This is a Task.
{
  for (;;) // A Task shall never return or exit.
  {
    display.poll();  
    vTaskDelay(1);  // one tick delay (15ms)
  }
}

void TaskVentilator( void *pvParameters __attribute__((unused)) )  // This is a Task.
{
  for (;;)
  {
    if (Serial.available()) {      // TODO semaphore for serial
      int r = Serial.read();
      switch(r){
        case 'a':
          valve_A_open();
          break;
        case 's':
          valve_B_open();
          break;
        case 'd':
          valve_C_open();
          break;
        case 'f':
          valve_D_open();
          break;
          
        case 'w':
          valve_A_close();
          break;
        case 'e':
          valve_B_close();
          break;
        case 'r':
          valve_C_close();
          break;
        case 't':
          valve_D_close();
          break;
        
        default:
          break;
      }
    }
    
    statistics.poll();
    messaging.poll();
    delay(1);
 //   vTaskDelay(1);  // one tick delay (15ms)
  }
}

void TaskValve( void *pvParameters __attribute__((unused)) )  // This is a Task.
{
    
    
  float peep_target = 10;
  float bottle_kPa_target = 180;
  float bottle_p_begin = 0;
  float bottle_p_o2_target; 
  float bottle_p_range;
  float lung_pressure_target_cmH20 = 30;

  float p_act, p_o2, set_tv, slm_sum, set_rr, set_o2, set_ie;
  
  uint32_t last_insp_start_millis = 0;
  uint32_t last_exp_start_millis = 0;
  uint32_t ti = 0, te = 0;
  
  float delay_pe = 0;
  float delay_pi = 0;
  
  for (;;) // breathing cycle
  {
    // expiration phase
    last_exp_start_millis = millis();
    statistics.is_inspiration_from_automat = 0;
    valve_C_close(); // this is duplicate
    valve_D_open();
    uint8_t peep_target_reached = 0;
    uint8_t bottle_kPa_target_reached = 0;
    
    uint8_t fio2_state = 1; // state automat - fio2 mixing
        
    
    
    do{
      while( xSemaphoreTake( xStatisticsSemaphore, ( TickType_t ) 5 ) == pdFALSE ){ 
        vTaskDelay(1);
      }
      p_act = statistics.p_act;
      p_o2 = statistics.p_o2;
      set_o2 = statistics.set_o2;
      set_ie = statistics.set_ie;
      
      peep_target = statistics.set_peep;
      //bottle_kPa_target = 1/statistics.set_ie * 50 + 100; // 100 kPa -only for testing... range 150 to 250 kPa in bottle
      bottle_kPa_target = 200;
      
      lung_pressure_target_cmH20 = statistics.set_max_p;
      set_rr = statistics.set_rr;
      
      xSemaphoreGive( xStatisticsSemaphore );
      
      if(p_act <= peep_target){ // peep
        valve_D_close();
        peep_target_reached = 1;
      }
      if(p_o2 >= bottle_kPa_target){
        valve_A_close();
        valve_B_close();        
        bottle_kPa_target_reached = 1;
      }
      
      switch(fio2_state){
        case 1: // measure bottle at the beginning
          bottle_p_begin = p_o2;
          bottle_p_range = bottle_kPa_target - bottle_p_begin;
          bottle_p_o2_target = bottle_p_begin + bottle_p_range/79*(set_o2-21);

          if(set_o2 > 21){
            valve_A_open(); // start filling oxygen
            fio2_state = 2;
          }else{
            fio2_state = 3;
          }
          break;
        case 2: // oxygen filling
          if(p_o2 >= bottle_p_o2_target){
            valve_A_close();
            fio2_state = 3;
          }
          break;
        case 3:
          if(set_o2 < 100){
            valve_B_open();
            fio2_state = 4;
          }else{
            fio2_state = 5; 
            bottle_kPa_target_reached = 1;
          }
          break;
        case 4:
          if(p_o2 >= bottle_kPa_target){
            valve_B_close();
            fio2_state = 5;
            bottle_kPa_target_reached = 1;
          }
          break;
        default:
          break;
      }
      
      
    }while(!(peep_target_reached && bottle_kPa_target_reached)); // te phase end
    valve_D_close();
    valve_A_close();
    valve_B_close();  
    
    te = millis() - last_exp_start_millis;
    
    
    // PEEP -delay phase pe
    uint32_t one_cyce_ms = 60000 / set_rr; // How long shall breathing cycle take (ms)
    uint32_t te = millis() - last_exp_start_millis; 
    
    float TE;
    TE = one_cyce_ms/(1 + (set_ie));
    delay_pe = TE - te;
    
    /*
    When input pressure is low, bottle refilling takes longer time. This prolongs the expiration phase.
    If I:E is set to 1 (i.e. 1:1), the algorithm would prolong the inspiration phase too, thus lowering the RR.
    This may lead to undershooting set RR and therefore lowering the minute ventilation.
    We prefer to keep RR constant prior to I:E. Therefore we need to make correction if delay_pi was negative.  
    */
    
    if(delay_pi < 0 && delay_pe >= 0){  // 
      delay_pe += delay_pi; // prevent decreasing RR to keep I:E. RR has priority!
      if(delay_pe < 0) delay_pe = 0; // prevent accumulation of RR debt
    }

    if(delay_pe > MAX_PEEP_DELAY_MS){
      delay_pe = MAX_PEEP_DELAY_MS;
    }
    
    if(delay_pe > 0){
      vTaskDelay(delay_pe / (1000/configTICK_RATE_HZ));   
    }
    
    /*
        // PEEP -delay phase
    float one_cyce_ms = 60000 / set_rr; // How long shall breathing cycle take (ms)
    float last_cycle_without_delay_ms = millis() - last_insp_start_millis; // How long was the last breathing cycle excluding peep delay (ms)
    float peep_delay = one_cyce_ms - last_cycle_without_delay_ms; // new peep delay (ms)
    if(peep_delay < 0){
      // TODO cannot reach requested RR!
      peep_delay = 0;
    }
    if(peep_delay > MAX_PEEP_DELAY_MS){
      peep_delay = MAX_PEEP_DELAY_MS;
    }
    
    if(last_insp_start_millis == 0){ // first breath = wait generic time
       vTaskDelay(50);
    }else{
      vTaskDelay(peep_delay / (1000/configTICK_RATE_HZ));   
    }
    */
    
    // inspiration phase
    last_insp_start_millis = millis();
    statistics.is_inspiration_from_automat = 1;    
    vTaskDelay(2); // let the Statistics do the PEEP measurement

    valve_C_open();

    

    do{
      while( xSemaphoreTake( xStatisticsSemaphore, ( TickType_t ) 5 ) == pdFALSE ){ 
        vTaskDelay(1);
      }
      p_act = statistics.p_act;
      p_o2 = statistics.p_o2;
      set_tv = statistics.set_tv;
      slm_sum = statistics.slm_sum;
      xSemaphoreGive( xStatisticsSemaphore );
      
    }while((p_act < lung_pressure_target_cmH20) && (slm_sum < set_tv));

    valve_C_close();
    
    ti = millis() - last_insp_start_millis;

    // Plateau delay phase pi
    
    uint32_t ti = millis() - last_insp_start_millis; 
    
    float TI;
    TI = one_cyce_ms/(1 + (1/set_ie));
   
    delay_pi = TI - ti;
    
    /*
    When input pressure is low, bottle refilling takes longer time. This prolongs the expiration phase.
    If I:E is set to 1 (i.e. 1:1), the algorithm would prolong the inspiration phase too, thus lowering the RR.
    This may lead to undershooting set RR and therefore lowering the minute ventilation.
    We prefer to keep RR constant prior to I:E. Therefore we need to make correction if delay_pe was negative.  
    */
    
    if(delay_pe < 0 && delay_pi >= 0){  // 
      delay_pi += delay_pe; // prevent decreasing RR to keep I:E. RR has priority!
      if(delay_pi < 0) delay_pi = 0; // prevent accumulation of RR debt
    }     
    
    if(delay_pi > MAX_TI_DELAY_MS){
      delay_pi = MAX_TI_DELAY_MS;
    }
    
    if(delay_pi > 0){
      vTaskDelay(delay_pi / (1000/configTICK_RATE_HZ));   
    }
    
 //   vTaskDelay(1);  // one tick delay (15ms)
  }
}
