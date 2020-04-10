#include <Arduino.h>
#include <Arduino_FreeRTOS.h>
#include <semphr.h>  // add the FreeRTOS functions for Semaphores (or Flags).
#include "SFM3300.h"
#include "I2C.h"
#include "Statistics.h"
#include "Messaging.h" 
#include "Display.h"

// Declare a mutex Semaphore Handle which we will use to manage the Serial Port.
// It will be used to ensure only only one Task is accessing this resource at any time.
SemaphoreHandle_t xSerialSemaphore;

void TaskLCD( void *pvParameters );
void TaskVentilator( void *pvParameters );

void setup() {
  
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
    vTaskDelay(1);  // one tick delay (15ms) in between reads for stability
  }
  
}

void TaskVentilator( void *pvParameters __attribute__((unused)) )  // This is a Task.
{
  for (;;)
  {
    statistics.poll();
    messaging.poll();
    vTaskDelay(1);  // one tick delay (15ms) in between reads for stability
  }
}
