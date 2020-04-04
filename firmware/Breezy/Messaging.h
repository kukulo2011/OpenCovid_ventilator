
#ifndef MESSAGING_H
#define MESSAGING_H


class Messaging{
  public:
  uint8_t print_msg(void);
  uint8_t print_service_msg(void);
  
  uint8_t poll(void);

  private:
  
};

extern Messaging messaging;


#endif // #ifndef MESSAGING_H
