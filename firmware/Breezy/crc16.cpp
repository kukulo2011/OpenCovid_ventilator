#include "crc16.h"

#define           poly     0x1021          /* crc-ccitt mask */

uint16_t CRC16::get_crc16(char *text)
{
  uint8_t ch, i;

  good_crc = 0xffff;
  i = 0;
  while((ch=text[i])!=0)
  {
      update_good_crc(ch);
      i++;
  }
  augment_message_for_good_crc();

  return good_crc;
}

void CRC16::update_good_crc(uint8_t ch)
{
    uint8_t i, v, xor_flag;

    /*
    Align test bit with leftmost bit of the message byte.
    */
    v = 0x80;

    for (i=0; i<8; i++)
    {
        if (good_crc & 0x8000)
        {
            xor_flag= 1;
        }
        else
        {
            xor_flag= 0;
        }
        good_crc = good_crc << 1;

        if (ch & v)
        {
            /*
            Append next bit of message to end of CRC if it is not zero.
            The zero bit placed there by the shift above need not be
            changed if the next bit of the message is zero.
            */
            good_crc= good_crc + 1;
        }

        if (xor_flag)
        {
            good_crc = good_crc ^ poly;
        }

        /*
        Align test bit with next bit of the message byte.
        */
        v = v >> 1;
    }
}

void CRC16::augment_message_for_good_crc()
{
    uint8_t i, xor_flag;

    for (i=0; i<16; i++)
    {
        if (good_crc & 0x8000)
        {
            xor_flag= 1;
        }
        else
        {
            xor_flag= 0;
        }
        good_crc = good_crc << 1;

        if (xor_flag)
        {
            good_crc = good_crc ^ poly;
        }
    }
}
