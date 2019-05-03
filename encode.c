#pragma config FOSC = INTOSCCLK
#pragma config WDTE = OFF
#pragma config PWRTE = ON
#pragma config CP = OFF
#define OSC

#define _XTAL_FREQ 4000000
#define LED RB3
#include <xc.h>

void main() {
 TRISB = 0b00000000;
 TRISA = 0b00000000;
 int VALUE = 24;
 int CLOCK = 0;
 int MASK = 0b00010000;
 int ANS = 0;
 int i = 0;
 int SIGNAL = 0;
 
 while(1)
{
 //Preamble and start bit
 LED = 1;
 __delay_ms(0.6);
 LED = 0;
 __delay_ms(0.2);
 
 //Data bits
 while(i < 5)
{
 ANS = MASK & VALUE;
 if(ANS == 0)
 {LED = 0;}
 else
 {LED = 1;}
 
 __delay_ms(0.157);
 MASK = MASK >> 1;
 i = i + 1;
}

 i = 0;
 MASK = 0b00010000;

}
 return;
}
