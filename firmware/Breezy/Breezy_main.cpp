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
  float lung_pressure_target_cmH20 = 30;

  float p_act, p_o2;
  
  for (;;)
  {
    // expiration phase
    statistics.is_inspiration_from_automat = 0;
    valve_C_close();
    valve_A_open();
    valve_B_open();
    valve_D_open();
    uint8_t peep_target_reached = 0;
    uint8_t bottle_kPa_target_reached = 0;
    
    do{
      while( xSemaphoreTake( xStatisticsSemaphore, ( TickType_t ) 5 ) == pdFALSE ){ 
        vTaskDelay(1);
      }
      p_act = statistics.p_act;
      p_o2 = statistics.p_o2;
      
      peep_target = statistics.set_peep;
      bottle_kPa_target = 1/statistics.set_ie * 50 + 100; // 100 kPa -only for testing... range 150 to 250 kPa in bottle
      lung_pressure_target_cmH20 = statistics.set_max_p;
      
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
    }while(!(peep_target_reached && bottle_kPa_target_reached));
    valve_D_close();
    valve_A_close();
    valve_B_close();  
    
    // PEEP -delay phase
    vTaskDelay(50);
    
    // inspiration phase
    statistics.is_inspiration_from_automat = 1;    
    vTaskDelay(2); // let the Statistics do the PEEP measurement

    valve_C_open();


    do{
      while( xSemaphoreTake( xStatisticsSemaphore, ( TickType_t ) 5 ) == pdFALSE ){ 
        vTaskDelay(1);
      }
      p_act = statistics.p_act;
      p_o2 = statistics.p_o2;
      xSemaphoreGive( xStatisticsSemaphore );
      
    }while(p_act < lung_pressure_target_cmH20);

    valve_C_close();

    // Plateau delay phase
    vTaskDelay(30);
    
    
 //   vTaskDelay(1);  // one tick delay (15ms)
  }
}
