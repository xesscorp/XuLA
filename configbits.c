//*********************************************************************
// Module Name: main.c
//
// Copyright 2007 X Engineering Software Systems Corp.
// All rights reserved.
//
// Module Description:
// Configuration settings for the Microchip device.
//
// Revision: $Id$
//********************************************************************

#pragma	config	PLLDIV  = 6			// 24 MHz / 6 = 4 MHz input to PLL
#pragma	config	CPUDIV  = OSC1_PLL2	// CPU clock = 96 MHz PLL output / 2 = 48 MHz
#pragma	config	USBDIV  = 2			// USB clock = 96 MHz PLL output / 2 = 48 MHz
#pragma	config	FOSC    = HSPLL_HS	// HS oscillator, PLL enabled, HS used by USB	
#pragma	config	FCMEN   = OFF		// Fail-safe clock monitor enable/disable
#pragma	config	IESO    = OFF		// Internal/external osc. switchover enable/disable
#pragma config	PWRT    = ON		// Power-up timer enable/disable
#pragma	config	BOR     = ON		// Brown-out reset enable/disable
#pragma	config	BORV    = 1			// Brown-out voltage: 0=max, 3=min
#pragma	config	VREGEN  = ON		// USB voltage regulator enable/disable
#pragma	config	WDT     = OFF		// Watchdog timer enable/disable
#pragma	config	WDTPS   = 32768		// Watchdog timer postscaler
#pragma	config	MCLRE   = ON		// MCLR pin enable/disable
#pragma	config	LPT1OSC = OFF		// Low-power Timer1 osc. enable/disable
#pragma	config	PBADEN  = OFF		// PORTB ADC enable/disable
#pragma	config	CCP2MX  = ON		// CCP2 MUX: OFF=CCP2 I/O->RB3,ON=CCP2 I/O->RC1
#pragma	config	STVREN  = ON		// Stack full/underflow reset enable/disable
#pragma	config	LVP     = OFF		// Low-voltage ICSP enable/disable
#pragma	config	ICPRT   = OFF		// ICPORT enable/disable
#pragma	config	XINST   = OFF		// Extended instruction set enable/disable
#pragma	config	DEBUG   = OFF		// DEBUG port on RB6,RB7 enable/disable
#pragma	config	CP0     = OFF		// 0x0800-0x1FFF code-protect enable/disable
#pragma	config	CP1     = OFF		// 0x2000-0x3FFF code-protect enable/disable
#pragma	config	CP2     = OFF		// 0x4000-0x5FFF code-protect enable/disable
#pragma	config	CPB     = OFF		// 0x0000-0x07FF code-protect enable/disable
#pragma	config	CPD     = OFF		// EEPROM code-protect enable/disable
#pragma	config	WRT0    = OFF		// 0x0800-0x1FFF write-protect enable/disable
#pragma	config	WRT1    = OFF		// 0x2000-0x3FFF write-protect enable/disable
#pragma	config	WRT2    = OFF		// 0x4000-0x5FFF write-protect enable/disable
#pragma	config	WRTB    = ON		// 0x0000-0x07FF write-protect enable/disable
#pragma	config	WRTC    = OFF		// Configuration register write-protect enable/disable
#pragma	config	WRTD    = OFF		// EEPROM write-protect enable/disable
#pragma	config	EBTR0   = OFF		// 0x0800-0x1FFF table read-protect enable/disable
#pragma	config	EBTR1   = OFF		// 0x2000-0x3FFF table read-protect enable/disable
#pragma	config	EBTR2   = OFF		// 0x4000-0x5FFF table read-protect enable/disable
#pragma	config	EBTRB   = OFF		// 0x0000-0x07FF table read-protect enable/disable
		
