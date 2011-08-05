#include <EEPROM.h>

#include <string.h>
#include <avr/pgmspace.h>
#include <avr/interrupt.h>
#include <ctype.h>

const int clk = 2;
const int dta = 3;
const int led1 = 7;
const int led0 = 6;

const int VISIBLE_SIZE = 16;
const int BITMAP_SIZE = 1024;
const int MARGIN_SIZE = (BITMAP_SIZE - VISIBLE_SIZE)/2;
const int MARGIN_SPEED = 75;

int margin = MARGIN_SIZE;
enum FlipMode { RIGHTSIDE_UP, UPSIDE_DOWN} flipMode = RIGHTSIDE_UP;
volatile int currentColumn = 0;

const int numChars = BITMAP_SIZE/6;

byte scroll = 0;
volatile unsigned short marginCount = 0;
unsigned int dataMin = margin, dataMax = margin;

byte bitmap[BITMAP_SIZE];
int index = 0;

//////////////////////////////////////////////////////////////////////////////
// Commands:
//    Lnnn[_ttt] - scroll left n pixels with optional delay time between scrolls
//    Rnnn - scroll right n pixels
//    Pnnn - set 'cursor' to postition nnn
//    C - clear display
//    S... - Draw text '...' starting at cursor position, end command with \n
//         increments the cursor by 6 positions per character.  Stops at the end.
//    Bxx... - Add raw bytes (specified as hex) to the buffer.  Increments the cursor
//         by one position per byte.  Stops at the end.
//    Un - scroll up n pixels destructively
//    Dn - scroll down n pixels destructively
//    Mnum - Set the margin (the first pixel of the visible area) to num
//    Fn - Flip - 0 = rightside-up, 1 = upside-down
//
//////////////////////////////////////////////////////////////////////////////
enum LedState { NONE, Lnum, Rnum, Pnum, Sstr, Bxx, Un, Dn, Mnum, Fn, Lttt };
LedState st = NONE;
char buf[numChars + 2];
int bufPos;
int bufReq;

void handleNONE(byte b);
void handleLnum(byte b);
void handleLttt(byte b);
void handleRnum(byte b);
void handlePnum(byte b);
void handleUn(byte b);
void handleDn(byte b);
void handleFn(byte b);
void handleSstr(byte b);
void handleBxx(byte b);
void clearDisplay();
void shiftLeft();
void setDelayedLeftShift();
void setDelayedLeftTime();
void shiftRight();
void setIndex();
void setFlip();
byte getByte(char c, byte offset);
byte flipByte(byte b);

const byte charset[][5] PROGMEM = {
                         0x00, 0x00, 0x00, 0x00, 0x00, // SPACE
                         0x00, 0x00, 0x5F, 0x00, 0x00, // !
                         0x00, 0x03, 0x00, 0x03, 0x00, // "
                         0x14, 0x3E, 0x14, 0x3E, 0x14, // #
                         0x24, 0x2A, 0x7F, 0x2A, 0x12, // $
                         0x43, 0x33, 0x08, 0x66, 0x61, // %
                         0x36, 0x49, 0x55, 0x22, 0x50, // &
                         0x00, 0x05, 0x03, 0x00, 0x00, // '
                         0x00, 0x1C, 0x22, 0x41, 0x00, // (
                         0x00, 0x41, 0x22, 0x1C, 0x00, // )
                         0x14, 0x08, 0x3E, 0x08, 0x14, // *
                         0x08, 0x08, 0x3E, 0x08, 0x08, // +
                         0x00, 0x50, 0x30, 0x00, 0x00, // ,
                         0x08, 0x08, 0x08, 0x08, 0x08, // -
                         0x00, 0x60, 0x60, 0x00, 0x00, // .
                         0x20, 0x10, 0x08, 0x04, 0x02, // /
                         0x3E, 0x51, 0x49, 0x45, 0x3E, // 0
                         0x00, 0x04, 0x02, 0x7F, 0x00, // 1
                         0x42, 0x61, 0x51, 0x49, 0x46, // 2
                         0x22, 0x41, 0x49, 0x49, 0x36, // 3
                         0x18, 0x14, 0x12, 0x7F, 0x10, // 4
                         0x27, 0x45, 0x45, 0x45, 0x39, // 5
                         0x3E, 0x49, 0x49, 0x49, 0x32, // 6
                         0x01, 0x01, 0x71, 0x09, 0x07, // 7
                         0x36, 0x49, 0x49, 0x49, 0x36, // 8
                         0x26, 0x49, 0x49, 0x49, 0x3E, // 9
                         0x00, 0x36, 0x36, 0x00, 0x00, // :
                         0x00, 0x56, 0x36, 0x00, 0x00, // ;
                         0x08, 0x14, 0x22, 0x41, 0x00, // <
                         0x14, 0x14, 0x14, 0x14, 0x14, // =
                         0x00, 0x41, 0x22, 0x14, 0x08, // >
                         0x02, 0x01, 0x51, 0x09, 0x06, // ?
                         0x3E, 0x41, 0x59, 0x55, 0x5E, // @
                         0x7E, 0x09, 0x09, 0x09, 0x7E, // A
                         0x7F, 0x49, 0x49, 0x49, 0x36, // B
                         0x3E, 0x41, 0x41, 0x41, 0x22, // C
                         0x7F, 0x41, 0x41, 0x41, 0x3E, // D
                         0x7F, 0x49, 0x49, 0x49, 0x41, // E
                         0x7F, 0x09, 0x09, 0x09, 0x01, // F
                         0x3E, 0x41, 0x41, 0x49, 0x3A, // G
                         0x7F, 0x08, 0x08, 0x08, 0x7F, // H
                         0x00, 0x41, 0x7F, 0x41, 0x00, // I
                         0x30, 0x40, 0x40, 0x40, 0x3F, // J
                         0x7F, 0x08, 0x14, 0x22, 0x41, // K
                         0x7F, 0x40, 0x40, 0x40, 0x40, // L
                         0x7F, 0x02, 0x0C, 0x02, 0x7F, // M
                         0x7F, 0x02, 0x04, 0x08, 0x7F, // N
                         0x3E, 0x41, 0x41, 0x41, 0x3E, // O
                         0x7F, 0x09, 0x09, 0x09, 0x06, // P
                         0x1E, 0x21, 0x21, 0x21, 0x5E, // Q
                         0x7F, 0x09, 0x09, 0x09, 0x76, // R
                         0x26, 0x49, 0x49, 0x49, 0x32, // S
                         0x01, 0x01, 0x7F, 0x01, 0x01, // T
                         0x3F, 0x40, 0x40, 0x40, 0x3F, // U
                         0x1F, 0x20, 0x40, 0x20, 0x1F, // V
                         0x7F, 0x20, 0x10, 0x20, 0x7F, // W
                         0x41, 0x22, 0x1C, 0x22, 0x41, // X
                         0x07, 0x08, 0x70, 0x08, 0x07, // Y
                         0x61, 0x51, 0x49, 0x45, 0x43, // Z
                         0x00, 0x00, 0x00, 0x00, 0x00, // place holder
                         0x00, 0x7F, 0x41, 0x00, 0x00, // [
                         0x02, 0x04, 0x08, 0x10, 0x20, // \
                         0x00, 0x00, 0x41, 0x7F, 0x00, // ]
                         0x04, 0x02, 0x01, 0x02, 0x04, // ^
                         0x40, 0x40, 0x40, 0x40, 0x40, // _
                         0x00, 0x01, 0x02, 0x04, 0x00, // `
                         
                         0x20, 0x54, 0x54, 0x54, 0x78, // a
                         0x7F, 0x44, 0x44, 0x44, 0x38, // b
                         0x38, 0x44, 0x44, 0x44, 0x44, // c
                         0x38, 0x44, 0x44, 0x44, 0x7F, // d
                         0x38, 0x54, 0x54, 0x54, 0x18, // e
                         0x04, 0x04, 0x7E, 0x05, 0x05, // f
                         0x08, 0x54, 0x54, 0x54, 0x3C, // g
                         0x7F, 0x08, 0x04, 0x04, 0x78, // h
                         0x00, 0x44, 0x7D, 0x40, 0x00, // i
                         0x20, 0x40, 0x44, 0x3D, 0x00, // j
                         0x7F, 0x10, 0x28, 0x44, 0x00, // k
                         0x00, 0x41, 0x7F, 0x40, 0x00, // l
                         0x7C, 0x04, 0x78, 0x04, 0x78, // m
                         0x7C, 0x08, 0x04, 0x04, 0x78, // n
                         0x38, 0x44, 0x44, 0x44, 0x38, // o
                         0x7C, 0x14, 0x14, 0x14, 0x08, // p
                         0x08, 0x14, 0x14, 0x14, 0x7C, // q
                         0x00, 0x7C, 0x08, 0x04, 0x04, // r
                         0x48, 0x54, 0x54, 0x54, 0x20, // s
                         0x04, 0x04, 0x3F, 0x44, 0x44, // t
                         0x3C, 0x40, 0x40, 0x20, 0x7C, // u
                         0x1C, 0x20, 0x40, 0x20, 0x1C, // v
                         0x3C, 0x40, 0x30, 0x40, 0x3C, // w
                         0x44, 0x28, 0x10, 0x28, 0x44, // x
                         0x0C, 0x50, 0x50, 0x50, 0x3C, // y
                         0x44, 0x64, 0x54, 0x4C, 0x44, // z
                         0x00, 0x08, 0x36, 0x41, 0x41, // {
                         0x00, 0x00, 0x7F, 0x00, 0x00, // |
                         0x41, 0x41, 0x36, 0x08, 0x00, // }
                         0x02, 0x01, 0x02, 0x04, 0x02  // ~
                       };
    

void setup()
{
  pinMode(clk, OUTPUT);
  pinMode(dta, OUTPUT);
  pinMode(led1, OUTPUT);
  pinMode(led0, OUTPUT);
  //pinMode(13, OUTPUT);
  //digitalWrite(13, LOW);
  
  digitalWrite(clk, 0);
  digitalWrite(dta, 0);
  digitalWrite(led1, 0);
  digitalWrite(led0, 0);
  DDRB = 0x3F;
  PORTB = 0;
  Serial.begin(115200);

  memset(bitmap, 0, sizeof(bitmap));
  index = 0;
  
  /*
  for (int i=0; i < VISIBLE_SIZE; ++i)
  {
    //Serial.print("i "); //Serial.println(i);
    if (i % 6)
    {
      bitmap[i + margin] = getByte(i/6+33,(i % 6)-1);
    }
    else
    {
      bitmap[i + margin] = 0;
    }
  }
  */
  
  // Set up the timer interrupt
  TCCR2A = 2;  // WGM 2, top=oc2a, clear timer at top
  TCCR2B = 0;
  OCR2A = 750;
  TCNT2 = 0;
  TIFR2 = 7;
  GTCCR |= (1 << PSRASY);
  TIMSK2 |= (1 << OCIE2A);
  TCCR2B = 3;  // clk/32

  Serial.print("ready: margin size "); Serial.println(MARGIN_SIZE);
  
  for (int a=0; a < BITMAP_SIZE; ++a) {
    bitmap[a] = EEPROM.read(a);
  }
  recalcMinMax();
  scroll = 1;
}

void loop()
{ 
  while (Serial.available())
  {
    byte b = Serial.read();
    
    Serial.print("b ["); Serial.print(b);
    Serial.print("] buf ["); Serial.print(buf);
    Serial.print("] index ["); Serial.print((short)index);
    Serial.print("] currentColumn ["); Serial.print((short)currentColumn);
    Serial.print("] st ["); Serial.print(st); Serial.println("]");
    
    switch (st)
    {
      case NONE:
        handleNONE(b);
        break;
      case Lnum:
        handleLnum(b);
        break;
      case Lttt:
        handleLttt(b);
        break;
      case Rnum:
        handleRnum(b);
        break;
      case Sstr:
        handleSstr(b);
        break;
      case Pnum:
        handlePnum(b);
        break;
      case Bxx:
        handleBxx(b);
        break;
      case Un:
	handleUn(b);
        break;
      case Dn:
	handleDn(b);
        break;
      case Mnum:
        handleMnum(b);
        break;
      case Fn:
        handleFn(b);
        break;
      default:
        break;
    }
  }
}

void handleNONE(byte b)
{
  switch(b)
  {
    case 'L': case 'l':
      st = Lnum;
     bufReq = 4;
      bufPos = 0;
      break;
    case 'R': case 'r':
      st = Rnum;
     bufReq = 4;
      bufPos = 0;
      break;
    case 'S': case 's':
      st = Sstr;
      bufReq = numChars - index/6;
      bufPos = 0;
      recalcMinMax();
      break;
    case 'C': case 'c':
      clearDisplay();
      recalcMinMax();
      break;
    case 'B': case 'b':
      st = Bxx;
      bufPos = 0;
      bufReq = 2 * (BITMAP_SIZE-bufPos);
      recalcMinMax();
      break;
    case 'P':case 'p':
      st = Pnum;
      bufPos = 0;
      bufReq = 4;
      break; 
    case 'U':case 'u':
      //st = Un;
      bufPos = 0;
      bufReq = 1;
      break;
    case 'D':case 'd':
      //st = Dn;
      bufPos = 0;
      bufReq = 1;
      break;
    case 'F':case 'f':
      st = Fn;
      bufPos = 0;
      bufReq = 1;
      break;
    case 'M':case 'm':
      st = Mnum;
      bufPos = 0;
      bufReq = 4;
      break;
    case 'K':case 'k':
      scroll ^= 1;
      recalcMinMax();
      break;
    case 'V':case 'v':
      for (int a=0; a < BITMAP_SIZE; ++a) {
        EEPROM.write(a, bitmap[a]);
      }
      break;
    case 'o':case'O':
      for (int a=0; a < BITMAP_SIZE; ++a) {
        bitmap[a] = EEPROM.read(a);
      }
      recalcMinMax();
      break;
    default:
      break;
  }
}

void recalcMinMax()
{
  marginCount = 0;
    dataMin = 0; dataMax = BITMAP_SIZE-1;
    for (; dataMin < BITMAP_SIZE; ++dataMin) if (bitmap[dataMin]) break;
    for (; dataMax >= dataMin; --dataMax) if (bitmap[dataMax]) break; 
    if (dataMax <= dataMin) {
      scroll = 0;
    } else {
      if (dataMin >= VISIBLE_SIZE/2) {
        dataMin -= VISIBLE_SIZE/2;
      }
      margin = dataMin;
    }
    Serial.print("dataMin "); Serial.print(dataMin);
    Serial.print("dataMax "); Serial.println(dataMax);
}

void handleLnum(byte b)
{
  if (isdigit(b))
  {
    buf[bufPos++] = b;
  }
  if (!isdigit(b) || bufPos == bufReq)
  {
    buf[bufPos] = 0;
    if (b == '_')
    {
    	setDelayedLeftShift();
	st = Lttt;
	return;
    }
    else
    {
    	shiftLeft();
    	st = NONE;
    	handleNONE(b);
    }
  }
}

void handleLttt(byte b)
{
  if (isdigit(b))
  {
    buf[bufPos++] = b;
  }
  if (!isdigit(b) || bufPos == bufReq)
  {
    buf[bufPos] = 0;
    setDelayedLeftTime();
    st = NONE;
    handleNONE(b);
  }
}

void handleRnum(byte b)
{
  if (isdigit(b))
  {
    buf[bufPos++] = b;
  }
  if (!isdigit(b) || bufPos == bufReq)
  {
    buf[bufPos] = 0;
    shiftRight();
    st = NONE;
    handleNONE(b);
  }
}

void handlePnum(byte b)
{
  if (isdigit(b))
  {
    buf[bufPos++] = b;
  }
  if (!isdigit(b) || bufPos == bufReq)
  {
    buf[bufPos] = 0;
    setIndex();
    st = NONE;
    handleNONE(b);
  }
}

void handleMnum(byte b)
{
  if (isdigit(b))
  {
    buf[bufPos++] = b;
  }
  if (!isdigit(b) || bufPos == bufReq)
  {
    buf[bufPos] = 0;
    setMargin();
    st = NONE;
    handleNONE(b);
  }
}

void handleFn(byte b)
{
  if (isdigit(b))
  {
    buf[bufPos++] = b;
  }
  if (!isdigit(b) || bufPos == bufReq)
  {
    buf[bufPos] = 0;
    setFlip();
    st = NONE;
    handleNONE(b);
  }
}

void handleSstr(byte b)
{
  byte c = b;
  if (b >= ' ' && b <= '~')
  {
    //Serial.print("bufreq "); //Serial.println(bufReq);
    b -= ' ';
    for (int i=0; index < BITMAP_SIZE && i < 5; ++i)
    {
      bitmap[index++] = getByte(b,i);
    }
    if (index < BITMAP_SIZE)
    {
      bitmap[index++] = 0;
    }
    --bufReq;
  }
  if (bufReq == 0 || c == '\r' || c == '\n')
  {
    st = NONE;
  }
}

void handleBxx(byte b)
{
  if (isxdigit(b))
  {
    buf[bufPos++] = b;
    --bufReq;
  } 
  else
  {
    Serial.println("end (non-xdigit)");
    st = NONE;
    handleNONE(b);
    return;
  }
  if (bufPos == 2 || bufReq == 0)
  {
    buf[bufPos] = 0;
    bitmap[index++] = (byte)strtoul(buf, NULL, 16);
    Serial.print("bufreq ");
    Serial.println((short)bufReq);
    Serial.print("bitmap[");
    Serial.print((short)index-1);
    Serial.print("] = ");
    Serial.println((short)bitmap[index-1]);
    if (bufReq == 0)
    {
      Serial.println("end");
      st = NONE;
      return;
    }
    bufPos = 0;
  }
}

void handleUn(byte b)
{
}

void handleDn(byte b)
{
}


void clearDisplay()
{
  memset(bitmap, 0, sizeof(bitmap));
}

void shiftLeft()
{
  int ct = atoi(buf);
  if (ct > BITMAP_SIZE)
  {
    ct = BITMAP_SIZE;
  }
  
  //Serial.print("&bitmap[0]: "); //Serial.println((unsigned long)&bitmap[0]);
  //Serial.print("Shifting left "); //Serial.print(ct); //Serial.println(" bytes");
  memmove(&bitmap[0], &bitmap[ct], BITMAP_SIZE-ct);
  memset(&bitmap[BITMAP_SIZE-ct], 0, ct);
}

void shiftRight()
{
  int ct = atoi(buf);
  if (ct > BITMAP_SIZE)
  {
    ct = BITMAP_SIZE;
  }
  
  memmove(&bitmap[ct], &bitmap[0], BITMAP_SIZE-ct);
  memset(&bitmap[0], 0, ct);
}

void setIndex()
{
  index = atoi(buf);
  if (index > BITMAP_SIZE)
  {
    index = BITMAP_SIZE;
  }
}

void setMargin()
{
  margin = atoi(buf);
  if (margin > BITMAP_SIZE)
  {
    margin = BITMAP_SIZE;
  }
  //Serial.print("new margin size: ");
  //Serial.println(margin);
}

void setFlip()
{
  byte f = atoi(buf) & 1;
  flipMode = (FlipMode)f;
  //Serial.print("new flip value: ");
  //Serial.println((short)flipMode);
}

void setDelayedLeftShift()
{
}

void setDelayedLeftTime()
{
}

byte getByte(char c, byte offset)
{ 
  byte b = pgm_read_byte(&charset[c][offset]); 
  return flipByte(b);
}

byte flipByte(byte b)
{
  byte ret = 0;
  byte bbb = 64, ccc = 1;
  for (byte i=0; i < 7; ++i)
  {    
    if (b & bbb)
    {
      ret |= ccc;
    }
    bbb >>= 1;
    ccc <<= 1;
  }
  return ret;
}

ISR(TIMER2_COMPA_vect,ISR_NOBLOCK)
{
    int idx = currentColumn;

    if (flipMode == UPSIDE_DOWN)
    {
      idx = VISIBLE_SIZE - currentColumn - 5;
    }
    byte b = bitmap[idx + margin];
    if (flipMode == UPSIDE_DOWN)
    {
      b = flipByte(b);
    }
    
    if (currentColumn == 0)
    {
      digitalWrite(dta, HIGH);
    }
    else
    {
      digitalWrite(dta, LOW);
    }
    
    PORTB = 0;
    digitalWrite(led1, LOW);
    digitalWrite(led0, LOW);
    
    digitalWrite(clk, HIGH);
    digitalWrite(clk, LOW);
    
    PORTB = (b >> 2);
    digitalWrite(led1, (b & 0x2) ? HIGH : LOW);
    digitalWrite(led0, (b & 0x1) ? HIGH : LOW);
    if (++currentColumn == VISIBLE_SIZE)
    {
      currentColumn = 0;
    }
    
    if (scroll && ++marginCount == MARGIN_SPEED) {
      marginCount = 0;
      if (++margin == dataMax) {
        margin = dataMin;
      }
    }
      
    
    //digitalWrite(13, LOW);
}
