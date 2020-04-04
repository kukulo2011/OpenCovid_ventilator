#ifndef CRC16_H
#define CRC16_H


#include <Arduino.h>

class CRC16
{
  public:
  uint16_t CRC16::get_crc16(char *text);


  private:
  uint16_t good_crc;
  void update_good_crc(uint8_t ch);
  void augment_message_for_good_crc();
  
};

extern CRC16 Crc16;



#endif // #ifndef CRC16_H
