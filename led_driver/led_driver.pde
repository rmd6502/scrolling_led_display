#include <string.h>
#include <avr/pgmspace.h>
#include <ctype.h>

const int clk = 2;
const int dta = 3;
const int led7 = 7;

const int VISIBLE_SIZE = 100;
const int BITMAP_SIZE = 1026;
const int MARGIN_SIZE = (BITMAP_SIZE - VISIBLE_SIZE)/2;

const int numChars = BITMAP_SIZE/6;

byte bitmap[BITMAP_SIZE];
int index = 0;



//////////////////////////////////////////////////////////////////////////////
// Commands:
//    Lnnn - scroll left n pixels
//    Rnnn - scroll right n pixels
//    Pnnn - set 'cursor' to postition nnn
//    C - clear display
//    S... - Draw text '...' starting at cursor position, end command with \n
//         increments the cursor by 6 positions per character.  Stops at the end.
//    Bxx... - Add raw bytes (specified as hex) to the buffer.  Increments the cursor
//         by one position per byte.  Stops at the end.
//    Un - scroll up n pixels destructively
//    Dn - scroll down n pixels destructively
//
//////////////////////////////////////////////////////////////////////////////
enum LedState { NONE, Lnum, Rnum, Pnum, Sstr, Bxx, Un, Dn };
LedState st = NONE;
char buf[numChars + 2];
int bufPos;
int bufReq;

void handleNONE(byte b);
void handleLnum(byte b);
void handleRnum(byte b);
void handlePnum(byte b);
void handleUn(byte b);
void handleDn(byte b);
void handleSstr(byte b);
void handleBxx(byte b);
void clearDisplay();
void shiftLeft();
void shiftRight();
void setIndex();
byte getByte(char c, byte offset);

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
                         0x00, 0x7F, 0x41, 0x00, 0x00, // [
                         0x02, 0x04, 0x08, 0x10, 0x20, // \
                         0x00, 0x00, 0x41, 0x7F, 0x00, // ]
                         0x04, 0x02, 0x01, 0x02, 0x04, // ^
                         0x40, 0x40, 0x40, 0x40, 0x40, // _
                         0x00, 0x01, 0x02, 0x04, 0x00, // `
                         0x00, 0x00, 0x00, 0x00, 0x00, // place holder
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
  pinMode(led7, OUTPUT);
  
  digitalWrite(clk, 0);
  digitalWrite(dta, 0);
  digitalWrite(led7, 0);
  DDRB = 0x3F;
  PORTB = 0;
  Serial.begin(115200);

  memset(bitmap, 0, sizeof(bitmap));
  index = 0;
  
  for (int i=0; i < VISIBLE_SIZE; ++i)
  {
    Serial.print("i "); Serial.println(i);
    if (i % 6)
    {
      bitmap[i + MARGIN_SIZE] = getByte(i/6+33,(i % 6)-1);
    }
    else
    {
      bitmap[i + MARGIN_SIZE] = 0;
    }
  }
  Serial.print("ready: margin size "); Serial.println(MARGIN_SIZE);
}

void loop()
{
  for (int i = 0; i < VISIBLE_SIZE; ++i)
  {
    byte b = bitmap[i + MARGIN_SIZE];
    
    if (i == 0)
    {
      digitalWrite(dta, HIGH);
    }
    else
    {
      digitalWrite(dta, LOW);
    }
    
    PORTB = 0;
    digitalWrite(led7, LOW);
    
    digitalWrite(clk, HIGH);
    digitalWrite(clk, LOW);
    
    PORTB = b & 0x3f;
    digitalWrite(led7, (b & 0x40) ? HIGH : LOW);
    
    delayMicroseconds(150);
  }
  
  if (Serial.available())
  {
    byte b = Serial.read();
    
    Serial.print("b "); Serial.print(b);
    Serial.print(" buf "); Serial.print(buf);
    Serial.print(" index "); Serial.print((short)index);
    Serial.print(" st "); Serial.println(st);
    
    switch (st)
    {
      case NONE:
        handleNONE(b);
        break;
      case Lnum:
        handleLnum(b);
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
      break;
    case 'C': case 'c':
      clearDisplay();
      break;
    case 'B': case 'b':
      st = Bxx;
      bufPos = 0;
      bufReq = 2 * (BITMAP_SIZE-bufPos);
      break;
    case 'P':case 'p':
      st = Pnum;
      bufPos = 0;
      bufReq = 4;
      break; 
    case 'U':case 'u':
      st = Un;
      bufPos = 0;
      bufReq = 1;
      break;
    case 'D':case 'd':
      st = Dn;
      bufPos = 0;
      bufReq = 1;
      break;
    default:
      break;
  }
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
    shiftLeft();
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

void handleSstr(byte b)
{
  if (b >= ' ' && b <= '~')
  {
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
  if (bufReq == 0 || b == '\r' || b == '\n')
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
  if (!isxdigit(b) || bufPos == 2 || bufReq == 0)
  {
    buf[bufPos] = 0;
    bitmap[index++] = (byte)strtoul(buf, NULL, 16);
    if (!isxdigit(b) || bufReq == 0)
    {
      st = NONE;
      handleNONE(b);
      return;
    }
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

byte getByte(char c, byte offset)
{
  byte b = pgm_read_byte(&charset[c][offset]); 
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
  //return b;
}
  
