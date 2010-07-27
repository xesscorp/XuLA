//*********************************************************************
// Module Name: main.c
//
// Copyright 2010 X Engineering Software Systems Corp.
// All rights reserved.
//
// Module Description:
// Configuration settings for the Microchip device.
//
// Revision: $Id$
//********************************************************************

#pragma	config	CPUDIV  = NOCLKDIV	// CPU clock = PLL output = 48 MHz
#pragma	config	USBDIV  = OFF		// Only aplies to USB low-speed mode
#pragma	config	FOSC    = HS    	// HS oscillator, PLL enabled, HS used by USB
#pragma config  PLLEN   = ON        // Oscillator multiplied by four
#pragma config  PCLKEN  = ON        // Primary clock is enabled (not under software control)
#pragma	config	FCMEN   = OFF		// Fail-safe clock monitor enable/disable
#pragma	config	IESO    = OFF		// Internal/external osc. switchover enable/disable
#pragma config	PWRTEN  = ON		// Power-up timer enable/disable
#pragma	config	BOREN   = ON		// Brown-out reset enable/disable
#pragma	config	BORV    = 30		// Brown-out voltage = 3.0V
#pragma	config	WDTEN   = OFF		// Watchdog timer enable/disable
#pragma	config	WDTPS   = 32768		// Watchdog timer postscaler
#pragma	config	MCLRE   = ON		// MCLR pin enable/disable
#pragma config  HFOFST  = OFF       // Wait until internal oscillator has stabilized
#pragma	config	STVREN  = ON		// Stack full/underflow reset enable/disable
#pragma	config	LVP     = OFF		// Low-voltage ICSP enable/disable
#pragma config  BBSIZ   = ON        // Boot block from 0x0000 to 0x07FF
#pragma	config	XINST   = OFF		// Extended instruction set enable/disable
#pragma	config	CP0     = OFF		// Block 0 code-protect enable/disable
#pragma	config	CP1     = OFF		// Block 1 code-protect enable/disable
#pragma	config	CPB     = OFF		// Boot block code-protect enable/disable
#pragma	config	CPD     = OFF		// Data EEPROM code-protect enable/disable
#pragma	config	WRT0    = OFF		// Block 0 write-protect enable/disable
#pragma	config	WRT1    = OFF		// Block 1 write-protect enable/disable
#pragma	config	WRTB    = ON		// Boot block write-protect enable/disable
#pragma	config	WRTC    = OFF		// Configuration register write-protect enable/disable
#pragma	config	WRTD    = OFF		// Data EEPROM write-protect enable/disable
#pragma	config	EBTR0   = OFF		// Block 0 table read-protect enable/disable
#pragma	config	EBTR1   = OFF		// Block 1 table read-protect enable/disable
#pragma	config	EBTRB   = OFF		// Boot block read-protect enable/disable
		
