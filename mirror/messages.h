#include <avr/pgmspace.h>

const char msg1[] PROGMEM = "Hello";
const char msg2[] PROGMEM = "Goodbye";

PGM_P messages[] PROGMEM =  {
  msg1,
  msg2
};

#define NUM_MESSAGES (sizeof(messages)/sizeof(PGM_P))
