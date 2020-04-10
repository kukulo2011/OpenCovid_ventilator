/*
  
  >>> Before compiling: Please remove comment from the constructor of the 
  >>> connected graphics display (see below).
  
  Universal 8bit Graphics Library, https://github.com/olikraus/u8glib/
  
  Copyright (c) 2012, olikraus@gmail.com
  All rights reserved.

  Redistribution and use in source and binary forms, with or without modification, 
  are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice, this list 
    of conditions and the following disclaimer.
    
  * Redistributions in binary form must reproduce the above copyright notice, this 
    list of conditions and the following disclaimer in the documentation and/or other 
    materials provided with the distribution.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
  CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
  MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
  NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER 
  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.  
  
*/




#include "U8glib.h"
#include "Arduino.h"
#include "Configuration.h"
#include "Display.h"
#include "Statistics.h"


Display display;

U8GLIB_ST7920_128X64_1X u8g(LCD_EN_PIN, LCD_RW_PIN, LCD_DI_PIN);  // SPI Com: SCK = en = 23, MOSI = rw = 17, CS = di = 16


void draw(void) {
  uint8_t msg[40] = "";
  // graphic commands to redraw the complete screen should be placed here  
  u8g.setFont(u8g_font_5x7);
  //u8g.setFont(u8g_font_osb21);
  

  sprintf(msg, "Ppeak" );
  dtostrf(statistics.p_peak, 5, 1, &msg[strlen(msg)]);
  u8g.drawStr( 0, 7, msg);

  sprintf(msg, "Pmean" );
  dtostrf(statistics.p_mean, 5, 0, &msg[strlen(msg)]);
  u8g.drawStr( 0, 14, msg);

  sprintf(msg, "PEEP " );
  dtostrf(statistics.peep, 5, 0, &msg[strlen(msg)]);
  u8g.drawStr( 0, 21, msg);

  sprintf(msg, "RR   " );
  dtostrf(statistics.rr, 5, 0, &msg[strlen(msg)]);
  u8g.drawStr( 0, 28, msg);

  sprintf(msg, "O2per" );
  dtostrf(statistics.o2_perc, 5, 0, &msg[strlen(msg)]);
  u8g.drawStr( 0, 35, msg);

  sprintf(msg, "Ti   " );
  dtostrf(statistics.ti, 5, 2, &msg[strlen(msg)]);
  
  
  if(statistics.i_e > 1){
    sprintf(msg, "I:E  " );
    dtostrf(statistics.i_e, 0, 1, &msg[strlen(msg)]);
    sprintf(&msg[strlen(msg)], ":1" );
  }else{
    sprintf(msg, "I:E  1:" );
    dtostrf(1.0 / statistics.i_e, 0, 1, &msg[strlen(msg)]);
  }
  
  u8g.drawStr( 64, 7, msg);

  sprintf(msg, "MVi" );
  dtostrf(statistics.mvi, 5, 1, &msg[strlen(msg)]);
  u8g.drawStr( 64, 14, msg);

  sprintf(msg, "MVe" );
  dtostrf(statistics.mve, 5, 1, &msg[strlen(msg)]);
  u8g.drawStr( 64, 21, msg);

  sprintf(msg, "VTi" );
  dtostrf(statistics.vti, 5, 0, &msg[strlen(msg)]);
  u8g.drawStr( 64, 28, msg);

  sprintf(msg, "VTe" );
  dtostrf(statistics.vte, 5, 0, &msg[strlen(msg)]);
  u8g.drawStr( 64, 35, msg);
}


uint8_t Display::poll(void)
{
  static uint32_t last_poll = 0;
  uint32_t mil = millis();
  
  if(mil - last_poll < (uint32_t)DISPLAY_PERIOD_MS){ // it is not the time yet
    return 0;
  }
  
  last_poll -= (uint32_t)DISPLAY_PERIOD_MS;

  display.hello();
  
  return 1;
  
}

void Display::init(void) {
  // flip screen, if required
  // u8g.setRot180();
  
  // set SPI backup if required
  //u8g.setHardwareBackup(u8g_backup_avr_spi);

  // assign default color value
  if ( u8g.getMode() == U8G_MODE_R3G3B2 ) {
    u8g.setColorIndex(255);     // white
  }
  else if ( u8g.getMode() == U8G_MODE_GRAY2BIT ) {
    u8g.setColorIndex(3);         // max intensity
  }
  else if ( u8g.getMode() == U8G_MODE_BW ) {
    u8g.setColorIndex(1);         // pixel on
  }
  else if ( u8g.getMode() == U8G_MODE_HICOLOR ) {
    u8g.setHiColorByRGB(255,255,255);
  }
}

void Display::hello(void) {

  u8g.firstPage();  
  do {
    draw();
  } while( u8g.nextPage() );
  
}
