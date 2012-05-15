#include <Print.h>

const int BITMAP_SIZE = 1024;

enum FlipMode { RIGHTSIDE_UP, UPSIDE_DOWN};
const int numChars = BITMAP_SIZE/6;

class LedScroller : public Print {
    private:
        int _clk;
        int _dta;
        int _ledPins[8];
        uint8_t _bitmap[BITMAP_SIZE];
        int _currentIndex;
        int _currentColumn;
        int _currentMargin;
        int _numCols;
        int _dataMax, _dataMin;
        enum FlipMode _flipMode;
        bool _scrollMode;
        int _scrollSpeed;

        void recalcMinMax();
        uint8_t getByte(char c, uint8_t offset);
        uint8_t flipByte(uint8_t b);
    public:
        LedScroller(int clk=2, int dta=3, int numCols = 16, int ledPins[] = NULL);
        void clearDisplay();
        size_t write(uint8_t c);
        void setIndex(int newIndex) { _currentIndex = newIndex; }
        void setMargin(int newMargin) { _currentMargin = newMargin; }
        void setFlip(enum FlipMode newFlip) { _flipMode = newFlip; }
        void setScrollMode(bool newMode) { _scrollMode = newMode; }
        void setScrollSpeed(int newSpeed) { _scrollSpeed = newSpeed; }
        void isr();
};
