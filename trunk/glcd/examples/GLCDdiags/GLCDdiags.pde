/*
 * GLCDdiags
 *
 * This sketch will test the memory and interface to the GLCD module as well as report
 * the current GLCD library configuration information to the serial port.
 *
 * It will also display a set of visual screens on the GLCD that can aid in diagnosing
 * misconfigured/wired chip select lines.
 *
 * The memory associated with each chip will be tested seperately.
 * Tests will be performed starting on chip #0.
 * The GLCD will go through a series of visual displays as the memory is
 * being tested. The test will attempt to display the chip # under test as
 * well as the x coordinate values under test using the memory and chip that is not under test.
 * If everthing is working and configured properly, chip #0 will be on the left
 * and each increasing chip # will advance to the right.
 *
 * Status and error information will also sent out the serial port while testing.
 *
 * The sketch peforms a few different memory tests but the main tests walk an incrementing pattern
 * through memory horizontally by incrementing through pages column at a time (left to right)
 * as well as vertically by incrementing throuh pages page a time (top to bottom).
 * 
 * NOTE:
 *   This sketch uses some internal GLCD library information that should 
 *   not normally used by sketches that use the GLCD library.
 *   
 */


#include <glcd.h>
#include "include/glcd_io.h"
#include "fonts/SystemFont5x7.h"       // system font

#include <avr/pgmspace.h>
#define P(name)   static const prog_char name[] PROGMEM   // declare a static string in AVR Progmem

#define MAX_ERRORS 10

#ifdef _AVRIO_AVRIO_
#define SerialPrintPINstr(x) \
  _SerialPrintPINstr(x, AVRIO_PIN2AVRPORT(AVRIO_PIN2AVRPIN(x)), AVRIO_PIN2AVRBIT(AVRIO_PIN2AVRPIN(x)))
#else
#define SerialPrintPINstr(x) _SerialPrintPINStr(x)
#endif

/*
 * declare a string for a horizontal line in program memory
 */
P(hline) =  "-----------------------------------------------------\n";


#define xstr(s) str(s)
#define str(...) #__VA_ARGS__

/*
 * Function to print a simple Quoted string to serial port.
 * The string is automagically forced to live in AVR flash/program space.
 */

#define SerialPrintQ(str) SerialPrintP(PSTR(str))

/*
 * print Progmem string to the serial port
 */
void SerialPrintP(  const prog_char * str )
{
  char c;
  const prog_char *p = str;

  while (c = pgm_read_byte(p++))
    Serial.print(c);   
}

#ifdef SERIALPRINTF

/*
 * Define a REAL printf since Arduino doesn't have one
 *
 * SerialPrintf() will automatically put the format string in AVR program space
 * 
 */

#define SerialPrintf(fmt, ...) _SerialPrintf(PSTR(fmt), ##__VA_ARGS__)

extern "C" {
  int serialputc(char c, FILE *fp) { 
    Serial.write(c); 
  }
}


void _SerialPrintf(const char *fmt, ...)
{
FILE stdiostr;
va_list ap;

  fdev_setup_stream(&stdiostr, serialputc, NULL, _FDEV_SETUP_WRITE);

  va_start(ap, fmt);
  vfprintf_P(&stdiostr, fmt, ap);
  va_end(ap);
}

/*
 * Define an eprintf() function for error output
 * (map it to the SerialPrintf() defined above)
 */
#define eprintf(...) SerialPrintf(__VA_ARGS__)

#endif //SERIALPRINTF


/*
 * GlcdPrintf() will automatically put the format string in AVR program space
 */
#define GlcdPrintf(fmt, ...) GLCD.Text.Printf_P(PSTR(fmt), ##__VA_ARGS__)


void setup()
{
  Serial.begin(9600);

#ifdef CORE_TEENSY
  delay(2000);    // allow USB time to come up.
                  // plus give user time to start serial monitor
                  // NOTE: for Teensy users:
                  //       Watch for the serial monitor icon in the IDE
                  //       to briefly "flash". When it does, USB is up and the IDE
                  //       has noticed the Teensy board. You can then click on the icon
                  //       to connect the teensy board virtual com port.
#endif

  delay(5);    // allow the hardware time settle
  SerialPrintQ("Serial initialized\n");
}


/*
 * Attempt to show some graphical information on
 * the display that will easily visually demonstrate
 * whether or not the chip select lines are properly
 * connected.
 */
void showchipselscreen(void)
{
  /*
   * draw a trangle
   */
  for(int x = 0; x < GLCD.Width; x++)
  {
     GLCD.DrawVLine( x, 0, map(x, 0, GLCD.Right, 0, GLCD.Bottom));
  }   
  /*
   * show sequential ascii characters 
   */
  GLCD.Text.CursorTo(0,2); 
  GLCD.Text.print("GLCD ver ");
  GLCD.Text.print(GLCD_VERSION, DEC); // no newline to prevent erase EOL
  GLCD.Text.CursorTo(0,3); 
  for(int i=0; i  < GLCD.Width / GLCD.CharWidth(' '); i++ )
  {
     GLCD.Text.print(char('A' + i)); // show the ascii character
  }
  GLCD.Text.print('\n');
  delay(5000);
  // show chips
  GLCD.ClearScreen();
  for(int chip = 0; chip < glcd_CHIP_COUNT; chip++)
  {
    GLCD.Text.CursorToXY(chip * CHIP_WIDTH,0);
    GLCD.Text.print("Chip:");
    GLCD.Text.print(chip);
  }

  delay(5000);
}

void  loop()
{   // run over and over again

  int lcount = 1;
  unsigned int glcdspeed, kops, kops_fract;

  /*
   * Dump GLCD config information *before* trying to talk to the GLCD
   * in case there is a problem talking to the GLCD.
   * This way ensures the GLCD information is always available.
   */

  /*
   * dump the GLCD library configuration information to
   * the serial port.
   */
  showGLCDconfig();

#ifdef XXX
  SerialPrintQ("Initializing GLCD\n");
  GLCD.Init();   // initialise the library, non inverted writes pixels onto a clear screen
  GLCD.Text.SelectFont(System5x7, BLACK);
#endif

  while(1)
  {

    SerialPrintP(hline);
    SerialPrintQ("Diag Loop: ");
    Serial.println(lcount);

    SerialPrintQ("Initializing GLCD\n");
    GLCD.Init();   // initialise the library, non inverted writes pixels onto a clear screen
    GLCD.Text.SelectFont(System5x7, BLACK);


    SerialPrintQ("Displaying ChipSelect Screens\n");
    showchipselscreen();
    if( lcdmemtest())
    {
      /*
       * memory tests failed.
       */
      SerialPrintQ("TEST FAILED\n");
    }
    else
    {
      SerialPrintQ("Tests PASSED\n");

      /*
       * Diags report loop count on completion
       */
      GLCD.ClearScreen();
      GLCD.Text.CursorTo(0,0);
      GLCD.Text.print("Diag Loop: ");
      GLCD.Text.println(lcount);
      GLCD.Text.println("Tests PASSED");

      /*
       * All GLCD tests passed so now
       * perform a GLCD "speed" test.
       */

      glcdspeed = getglcdspeed();
      /*
       * Calculate the speed in K operations/sec
       * Since the speed value reported is 10x the actual value,
       * Dividing by 100 gives the integer K ops/sec
       * Modulo 100 gives the factional K ops/sec
       */

      kops = glcdspeed/100;
      kops_fract = glcdspeed %100;

      GLCD.Text.print("K SetDot/s: ");
      GLCD.Text.print(kops);
      GLCD.Text.print(".");
      GLCD.Text.println(kops_fract);


      SerialPrintQ("GLCD.SetDot() speed (K ops/sec): ");
      Serial.print(kops);
      SerialPrintQ(".");
      Serial.println(kops_fract);
    }

    delay(5000);
    lcount++;
    GLCD.ClearScreen();
    /*
     * dump the GLCD library configuration information to
     * the serial port each loop in case it was missed the
     * the first time around.
     */
    showGLCDconfig();
  }
}


uint8_t lcdmemtest(void)
{
  uint8_t errors = 0;

  SerialPrintQ("Walking 1s data test\n");

  errors = lcdw1test();
  if(errors)
    return(errors);

  SerialPrintQ("Wr/Rd Chip Select Test\n");

  errors = lcdw1test();
  if(errors)
    return(errors);

  GLCD.ClearScreen();

  SerialPrintQ("Testing GLCD memory pages\n");

  uint8_t col = 0;
  uint8_t ecol = CHIP_WIDTH-1;
  for(uint8_t chip = 0; chip < glcd_CHIP_COUNT; chip++)
  {

    if(col >= CHIP_WIDTH)
      GLCD.Text.CursorToXY(0,0);
    else
      GLCD.Text.CursorToXY(CHIP_WIDTH,0);
    GLCD.Text.print("Chip:");
    GLCD.Text.print((int)chip);

    /*
     * Assumes font is 8 pixels high
     */
    if(col >= CHIP_WIDTH)
      GLCD.Text.CursorToXY(0,8);
    else
      GLCD.Text.CursorToXY(CHIP_WIDTH,8);
    GLCD.Text.print((int)col);
    GLCD.Text.print('-');
    GLCD.Text.print((int)ecol);
    delay(500);

//  SerialPrintf("Horizonal Page Test Chip: %d Pixels %d-%d\n", chip, col, ecol);

    SerialPrintQ("Horizonal Page Test Chip: ");
    Serial.print((int)chip);
    SerialPrintQ(" Pixels ");
    Serial.print((int)col);
    Serial.print('-');
    Serial.println((unsigned int)ecol);

    errors += lcdhpagetest(col, ecol, 0, GLCD.Height/8 - 1, 0, 255);


//  SerialPrintf("Vertical Page Test Chip: %d Pixels %d-%d\n", chip, col, ecol);

    SerialPrintQ("Vertical Page Test Chip: ");
    Serial.print((int)chip);
    SerialPrintQ(" Pixels ");
    Serial.print((int)col);
    Serial.print('-');
    Serial.println((int)ecol);

    errors += lcdvpagetest(col, ecol, 0, GLCD.Height/8 - 1, 0, 255);
    GLCD.ClearScreen();

    col += CHIP_WIDTH;
    ecol += CHIP_WIDTH;
    if(ecol > GLCD.Right)
      ecol = GLCD.Right;
  }


  GLCD.Text.CursorTo(0,0);
  GLCD.Text.print("Full Display");
  GLCD.Text.CursorTo(0,1);
  GLCD.Text.print((int)0);
  GLCD.Text.print('-');
  ((int)GLCD.Right);
  delay(1000);

//SerialPrintf("Full Module Horizontal Page Test:Pixels %d-%d\n",  0, GLCD.Right);

  SerialPrintQ("Full Module Horizontal Page Test:Pixels ");
  Serial.print(0);
  Serial.print('-');
  Serial.println((int)GLCD.Right);

  errors += lcdhpagetest(0, GLCD.Right, 0, GLCD.Bottom/8, 0, 255);

//SerialPrintf("Full Module Vertical Page Test:Pixels %d-%d\n",  0, GLCD.Right);

  SerialPrintQ("Full Module Vertical Page Test:Pixels ");
  Serial.print(0);
  Serial.print('-');
  Serial.println((int)GLCD.Right);

  errors += lcdvpagetest(0, GLCD.Right, 0, GLCD.Bottom/8, 0, 255);

  GLCD.ClearScreen();

  return(errors);
}

/*
 * Walk a bit through a single memory location to see if
 * basic reads/writes work.
 */

uint8_t
lcdw1test(void)
{
  uint8_t errors = 0;
  uint8_t data;

  for(uint8_t pat = 1;  pat != 0; pat <<= 1)
  {
    GLCD.GotoXY(0,0);
    GLCD.WriteData(pat);
    GLCD.GotoXY(0,0);
    data = GLCD.ReadData();

    if(data != pat)
    {
//    eprintf(" Compare error: %x != %x\n", data, pat);
      SerialPrintQ(" Compare error: ");
      Serial.print((unsigned int)data, HEX);
      SerialPrintQ(" != ");
      Serial.println((unsigned int)pat, HEX);

      errors++;
    }
  }
  return(errors);
}

/*
 * LCD read/write chip select test.
 * This test attempts to detect chip select issues by writing the chip number
 * to the lowest page of memory for each chip.
 * This is done incrementing and decrementing.
 * It must be done both ways because when chip selects are wrong, it is possible
 * to write to more than 1 chip at a time. To catch this, you have write do the operation
 * more tha once. Once by writing incrementing addresses and then decrementing addresses.
 */

uint8_t
lcdrwseltest()
{
  uint8_t errors = 0;
  uint8_t data;


  for(uint8_t chip = 0, addr = 0; chip < glcd_CHIP_COUNT; chip++, addr += CHIP_WIDTH)
  {
    GLCD.GotoXY(addr, 0);
    GLCD.WriteData(chip);
  }
  for(uint8_t chip = 0, addr = 0; chip < glcd_CHIP_COUNT; chip++, addr += CHIP_WIDTH)
  {
    GLCD.GotoXY(addr, 0);
    data = GLCD.ReadData();
    if(data != chip)
    {
//    eprintf(" Compare error: chip:%d %x != %x\n", chip, data, chip);
      SerialPrintQ(" Compare error: chip:");
      Serial.print((int)chip);
      Serial.print(' ');
      Serial.print((unsigned int)data, HEX);
      SerialPrintQ(" != ");
      Serial.println((unsigned int)chip, HEX);
      errors++;
    }
  }

  for(int chip = glcd_CHIP_COUNT - 1, addr = (glcd_CHIP_COUNT-1)*CHIP_WIDTH; chip >= 0; chip--, addr -= CHIP_WIDTH)
  {
    GLCD.GotoXY(addr, 0);
    GLCD.WriteData(chip);
  }
  for(int chip = glcd_CHIP_COUNT - 1, addr = (glcd_CHIP_COUNT-1)*CHIP_WIDTH; chip >= 0; chip--, addr -= CHIP_WIDTH)
  {
    GLCD.GotoXY(addr, 0);
    data = GLCD.ReadData();
    if(data != chip)
    {
//    eprintf(" Compare error: chip:%d  %x != %x\n", chip, data, chip);
      SerialPrintQ(" Compare error: chip:");
      Serial.print((int)chip);
      Serial.print(' ');
      Serial.print((unsigned int)data, HEX);
      SerialPrintQ(" != ");
      Serial.println((unsigned int)chip, HEX);
      errors++;
    }
  }

  return(errors);
}


/*
 * Walk incrementing values through incrementing memory locations.
 * 
 * A value starting at sval ending at eval will be walked through memory
 * pages horizontally.
 * The starting x location will be filled in with sval and the value will
 * incremented through all locations to be tested. Values are written through
 * incrementing x values and when the maximum x value is reached on a row/page,
 * writing is continued down on the next row/page.
 *
 * All the values are read and compared to expected values.
 *
 * Then process starts over again by incrementing the starting value.
 * This repeats until the starting value reaches the ending value.
 *
 * Each memory location will tested with an incrementing value evel-sval+1 times.
 *
 * If sval is 0 and eval is 255, every memory location will be tested for every value.
 *
 */


int lcdhpagetest(uint8_t x1, uint8_t x2, uint8_t spage, uint8_t epage, uint8_t sval, uint8_t eval)
{
  uint8_t x;
  uint8_t data;
  uint8_t rdata;
  uint8_t page;
  uint8_t errors = 0;

  /*
   * perform each interation of test across memory with an incrementing pattern
   * starting at sval and bumping sval each iteration.
   */
  do
  {
    /*
     * write out all glcd memory pages
     * sequentially through incrementing columns (x values)
     */

    data = sval;
    for(page = spage; page <= epage; page++)
    {

      GLCD.GotoXY(x1, page * 8);
      for(x = x1; x <= x2; x++)
      {
        /*
	 * GotoXY() is intentially not done here in the loop to 
         * let the hardware bump its internal address.
         * This ensures that the glcd code and hardware are
         * properly tracking each other.
         */
        GLCD.WriteData(data);
        data++;
      }
    }

    /*
     * Now go back and verify the pages
     */

    data = sval;
    for(page = spage; page <= epage; page++)
    {

      for(x = x1; x<= x2; x++)
      {
        /*
	 * Reads don't auto advance X
         */
        GLCD.GotoXY(x, page * 8);
        rdata = GLCD.ReadData();

        if(data != rdata)
        {
//        eprintf(" Verify error: (%d,%d) %x!=%x\n", x, spage*8, data, rdata);
          SerialPrintQ(" Verify error: (");
          Serial.print((unsigned int) x);
          Serial.print(',');
          Serial.print((unsigned int) (spage*8));
          SerialPrintQ(") ");
          Serial.print((unsigned int)data, HEX);
          SerialPrintQ("!=");
          Serial.println((unsigned int)rdata, HEX);

          if(++errors > MAX_ERRORS)
            return(errors);
        }
        data++;
      }
    }
  } 
  while(sval++ != eval);
  return(0);
}

/*
 * Walk incrementing values through vertical memory page locations.
 * 
 * A value starting at sval ending at eval will be walked through memory pages
 * Vertically.
 * The starting x location will be filled in with sval and the value will
 * incremented through all memory pages to be tested. Values are written through
 * incrementing row/page values and when the maximum row/page value is reached,
 * writing is continued at the top page of the next column/x location.
 *
 * All the values are read and compared to expected values.
 *
 * Then process starts over again by incrementing the starting value.
 * This repeats until the starting value reaches the ending value.
 *
 * Each memory location will tested with an incrementing value evel-sval+1 times.
 *
 * If sval is 0 and eval is 255, every memory location will be tested for every value.
 *
 */


int lcdvpagetest(uint8_t x1, uint8_t x2, uint8_t spage, uint8_t epage, uint8_t sval, uint8_t eval)
{
  uint8_t x;
  uint8_t data;
  uint8_t rdata;
  uint8_t page;
  uint8_t errors = 0;

  /*
   * perform each interation of test across memory with an incrementing pattern
   * starting at sval and bumping sval each iteration.
   */
  do
  {
    /*
     * write out all glcd memory pages
     * sequentially through incrementing columns (x values)
     */

    data = sval;
    for(x = x1; x <= x2; x++)
    {
      for(page = spage; page <= epage; page++)
      {
        GLCD.GotoXY(x, page * 8);
        GLCD.WriteData(data);
        data++;
      }
    }

    /*
     * Now go back and verify the pages
     */

    data = sval;
    for(x = x1; x<= x2; x++)
    {
      for(page = spage; page <= epage; page++)
      {
        GLCD.GotoXY(x, page * 8);
        rdata = GLCD.ReadData();

        if(data != rdata)
        {
//        eprintf(" Verify error: (%d,%d) %x!=%x\n", x, spage*8, data, rdata);

          SerialPrintQ(" Verify error: (");
          Serial.print((unsigned int) x);
          Serial.print(',');
          Serial.print((unsigned int) (spage*8));
          SerialPrintQ(") ");
          Serial.print((unsigned int)data, HEX);
          SerialPrintQ("!=");
          Serial.println((unsigned int)rdata, HEX);

          if(++errors > MAX_ERRORS)
            return(errors);
        }
        data++;
      }
    }
  } 
  while(sval++ != eval);
  return(0);
}

/*
 * Dump the GLCD configuration information out
 * the serial port.
 */

void showGLCDconfig(void)
{
  SerialPrintP(hline);
  SerialPrintQ("GLCD Lib Configuration: Library VER: ");
  Serial.println(GLCD_VERSION);
  SerialPrintP(hline);
  SerialPrintQ("Configuration:");
  SerialPrintQ(glcd_ConfigName);
  SerialPrintQ(" GLCD:");
  SerialPrintQ(glcd_DeviceName);
  Serial.print('\n');

//SerialPrintf("DisplayWidth:%d DisplayHeight:%d\n", GLCD.Width, GLCD.Height);
  SerialPrintQ("DisplayWidth:");
  Serial.print((int)GLCD.Width);
  SerialPrintQ(" DisplayHeight:");
  Serial.println((int)GLCD.Height);

//SerialPrintf("Chips:%d", glcd_CHIP_COUNT);
  SerialPrintQ("Chips:");
  Serial.print(glcd_CHIP_COUNT);


//SerialPrintf(" ChipWidth:%3d ChipHeight:%2d\n", CHIP_WIDTH, CHIP_HEIGHT);
  SerialPrintQ(" ChipWidth:");
  Serial.print(CHIP_WIDTH);
  SerialPrintQ(" ChipHeight:");
  Serial.println(CHIP_HEIGHT);

#ifdef glcdRES
  SerialPrintQ("RES:");
  SerialPrintPINstr(glcdRES);
#endif
#ifdef glcdCSEL1
  SerialPrintQ(" CSEL1:");
  SerialPrintPINstr(glcdCSEL1);
#endif
#ifdef glcdCSEL2
  SerialPrintQ(" CSEL2:");
  SerialPrintPINstr(glcdCSEL2);
#endif
#ifdef glcdCSEL3
  SerialPrintQ(" CSEL3:");
  SerialPrintPINstr(glcdCSEL3);
#endif
#ifdef glcdCSEL4
  SerialPrintQ(" CSEL4:");
  SerialPrintPINstr(glcdCSEL4);
#endif


  SerialPrintQ(" RW:");
  SerialPrintPINstr(glcdRW);

  SerialPrintQ(" DI:");
  SerialPrintPINstr(glcdDI);

#ifdef glcdEN
  SerialPrintQ(" EN:");
  SerialPrintPINstr(glcdEN);
#endif

#ifdef glcdE1
  SerialPrintQ(" E1:");
  SerialPrintPINstr(glcdE1);
#endif
#ifdef glcdE2
  SerialPrintQ(" E2:");
  SerialPrintPINstr(glcdE2);
#endif

  Serial.print('\n');

//  SerialPrintf("D0:%s", GLCDdiagsPIN2STR(glcdData0Pin));
  SerialPrintQ("D0:");
  SerialPrintPINstr(glcdData0Pin);

  SerialPrintQ(" D1:");
  SerialPrintPINstr(glcdData1Pin);

  SerialPrintQ(" D2:");
  SerialPrintPINstr(glcdData2Pin);

  SerialPrintQ(" D3:");
  SerialPrintPINstr(glcdData3Pin);

  SerialPrintQ(" D4:");
  SerialPrintPINstr(glcdData4Pin);

  SerialPrintQ(" D5:");
  SerialPrintPINstr(glcdData5Pin);

  SerialPrintQ(" D6:");
  SerialPrintPINstr(glcdData6Pin);

  SerialPrintQ(" D7:");
  SerialPrintPINstr(glcdData7Pin);

  Serial.print('\n');

//  SerialPrintf("Delays: tDDR:%d tAS:%d tDSW:%d tWH:%d tWL: %d\n",
//  GLCD_tDDR, GLCD_tAS, GLCD_tDSW, GLCD_tWH, GLCD_tWL);

  SerialPrintQ("Delays: tDDR:");
  Serial.print(GLCD_tDDR);
  SerialPrintQ(" tAS:");
  Serial.print(GLCD_tAS);
  SerialPrintQ(" tDSW:");
  Serial.print(GLCD_tDSW);
  SerialPrintQ(" tWH:");
  Serial.print(GLCD_tWH);
  SerialPrintQ(" tWL:");
  Serial.println(GLCD_tWL);


#ifdef glcd_CHIP0
  SerialPrintQ("ChipSelects:");
  SerialPrintQ(" CHIP0:");
  SerialPrintQ(xstr(glcd_CHIP0));
#endif
#ifdef glcd_CHIP1
  SerialPrintQ(" CHIP1:");
  SerialPrintQ(xstr(glcd_CHIP1));
#endif
#ifdef glcd_CHIP2
  SerialPrintQ(" CHIP2:");
  SerialPrintQ(xstr(glcd_CHIP2));
#endif
#ifdef glcd_CHIP3
  SerialPrintQ(" CHIP3:");
  SerialPrintQ(xstr(glcd_CHIP3));
#endif

#ifdef glcd_CHIP0
  Serial.print('\n');
#endif



#ifdef _AVRIO_AVRIO_
  /*
   * Show AVRIO GLCD data mode
   *
   * Requires getting down and dirty and mucking around done
   * in avrio land.
   */

  SerialPrintQ("Data mode: ");
  /*
   * First check for full 8 bit mode
   *
   */
  if(AVRDATA_8BIT(glcdData0Pin, glcdData1Pin, glcdData2Pin, glcdData3Pin,
  glcdData4Pin, glcdData5Pin, glcdData6Pin, glcdData7Pin))
  {
    /*
     * full 8 bit mode
     */
    SerialPrintQ("byte\n");
  }
  else
  {
    SerialPrintQ("\n d0-d3:");
    if(AVRDATA_4BITHI(glcdData0Pin, glcdData1Pin, glcdData2Pin, glcdData3Pin) ||
      AVRDATA_4BITLO(glcdData0Pin, glcdData1Pin, glcdData2Pin, glcdData3Pin))
    {
      SerialPrintQ("nibble mode");
#ifndef GLCD_ATOMIC_IO
      SerialPrintQ("-Non-Atomic");
#else
      SerialPrintQ("-disabled"); // for now this "knows" avrio disabled nibbles when in atomic mode.
#endif
    }
    else
    {
      SerialPrintQ("bit i/o");
    }

    SerialPrintQ("\n d4-d7:");

    if(AVRDATA_4BITHI(glcdData4Pin, glcdData5Pin, glcdData6Pin, glcdData7Pin) ||
      AVRDATA_4BITLO(glcdData4Pin, glcdData5Pin, glcdData6Pin, glcdData7Pin))
    {
      SerialPrintQ("nibble mode");
#ifndef GLCD_ATOMIC_IO
      SerialPrintQ("-Non-Atomic");
#else
      SerialPrintQ("-disabled"); // for now this "knows" avrio disabled nibbles when in atomic mode.
#endif
    }
    else
    {
      SerialPrintQ("bit i/o");
    }
    Serial.print('\n');
  }

#endif // _AVRIO_AVRIO_

  /*
   * Show font rendering:
   */

#ifdef GLCD_OLD_FONTDRAW
  SerialPrintQ("Text Render: ");
  SerialPrintQ("OLD\n");
#endif

  /*
   * show no scroll down if disabled.
   */

#ifdef GLCD_NO_SCROLLDOWN
  SerialPrintQ("NO Down Scroll");
#endif

}

#ifdef _AVRIO_AVRIO_
/*
 * The avrio version of the pin string also contain
 * the AVR port and bit number of the pin.
 * The format is PIN_Pb where P is the port A-Z 
 * and b is the bit number within the port 0-7
 */
void
_SerialPrintPINstr(uint8_t pin, uint8_t avrport, uint8_t avrbit)
{

  /*
   * Check to see if Ardino pin# is used or
   * if AVRPIN #s are used.
   */
  if(pin >= AVRIO_PIN(AVRIO_PORTA, 0))
  {
    
//  SerialPrintf("0x%x", pin);
    /*
     * print pin value in hex when AVRPIN #s are used
     */
    SerialPrintQ("0x");
    Serial.print(pin,HEX);
  }
  else
  {
//  SerialPrintf("%d", pin);
    Serial.print(pin,DEC);
  }

//SerialPrintf("(PIN_%c%d)", pin, 'A'-AVRIO_PORTA+avrport, avrbit);

  SerialPrintQ("(PIN_");
  Serial.print((char)('A' - AVRIO_PORTA+avrport));
  Serial.print((int)avrbit);
  Serial.print(')');

}
#else
void
_SerialPrintPINstr(uint16_t pin)
{
  Serial.print((int) pin);
}
#endif


/*
 * This function returns a composite "speed" of the glcd
 * by returning the SetDot() speed in 1/10 operations/sec.
 * i.e. return value is 1/10 the number of SetDot() calls
 * per second.
 */
uint16_t
getglcdspeed()
{
uint16_t iter = 0;
unsigned long startmillis;

  startmillis = millis();

  while(millis() - startmillis < 1000) // loop for 1 second
  {
    /*
     * Do 10 operations to minimize the effects of the millis() call
     * and the loop.
     *
     * Note: The pixel locations were chosen to ensure that a
     * a set colum and set page operation are needed for each SetDot()
     * call.
     * The intent is to get an overall feel for the speed of the GLD
     * as each SetDot() call will do these operations to the glcd:
     * - set page
     * - set column
     * - read byte (dummy read)
     * - read byte (real read)
     * - set column (set column back for write)
     * - write byte
     */

    GLCD.SetDot(GLCD.Right, GLCD.Bottom, WHITE);
    GLCD.SetDot(GLCD.Right-1, GLCD.Bottom-1, WHITE);
    GLCD.SetDot(GLCD.Right, GLCD.Bottom, WHITE);
    GLCD.SetDot(GLCD.Right-1, GLCD.Bottom-1, WHITE);
    GLCD.SetDot(GLCD.Right, GLCD.Bottom, WHITE);
    GLCD.SetDot(GLCD.Right-1, GLCD.Bottom-1, WHITE);
    GLCD.SetDot(GLCD.Right, GLCD.Bottom, WHITE);
    GLCD.SetDot(GLCD.Right-1, GLCD.Bottom-1, WHITE);
    GLCD.SetDot(GLCD.Right, GLCD.Bottom, WHITE);
    GLCD.SetDot(GLCD.Right-1, GLCD.Bottom-1, WHITE);
    iter++;
  }

  return(iter);

}