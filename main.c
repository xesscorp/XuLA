//*********************************************************************
// Module Name: main.c
//
// Copyright 2007 X Engineering Software Systems Corp.
// All rights reserved.
//
// Module Description:
// This module starts the USB-to-JTAG interface or else it controls
// the programming of the flash with a new program.
//
// Revision: $Id$
//********************************************************************

/** I N C L U D E S **********************************************************/
#include <p18cxxx.h>
#include "system\typedefs.h"                        // Required
#include "system\usb\usb.h"                         // Required
#include "io_cfg.h"                                 // Required

#include "system\usb\usb_compile_time_validation.h" // Optional

/** V A R I A B L E S ********************************************************/
#pragma udata

/** P R I V A T E  P R O T O T Y P E S ***************************************/

/** V E C T O R  R E M A P P I N G *******************************************/

#pragma code _HIGH_INTERRUPT_VECTOR = 0x000008
void _high_ISR (void)
{
    _asm goto RM_HIGH_INTERRUPT_VECTOR _endasm
}

#pragma code _LOW_INTERRUPT_VECTOR = 0x000018
void _low_ISR (void)
{
    _asm goto RM_LOW_INTERRUPT_VECTOR _endasm
}

#pragma code

/** D E C L A R A T I O N S **************************************************/
#pragma code
/******************************************************************************
 * Function:        void main(void)
 *
 * PreCondition:    None
 *
 * Input:           None
 *
 * Output:          None
 *
 * Side Effects:    None
 *
 * Overview:        Main program entry point.
 *
 * Note:            None
 *****************************************************************************/
void main(void)
{
//	byte temp;
//	temp = ADCON1;
	ADCON1 |= 0x0F;

	// enable PORTB pullups so RB5 pullup can also pullup RE1 on XSUSB 1.1 boards
	INTCON2bits.NOT_RBPU = 0;	// enable PORTB pullups
	LATBbits.LATB5 = 1;
    //TRISBbits.TRISB5 = 1;     // Reset value is already '1'

    //TRISBbits.TRISB4 = 1;     // Reset value is already '1'
    
    //Check Bootload Mode Entry Condition
    if(PORTEbits.RE1 == 1)      // If not pulled low, then User Mode
    {
		INTCON2bits.NOT_RBPU = 1;	// disable PORTB pullups
//		ADCON1 = temp;          // Restore reset value
        _asm goto RM_RESET_VECTOR _endasm
    }//end if
	INTCON2bits.NOT_RBPU = 1;	// disable PORTB pullups
    
    //Bootload Mode
	mInitAllLEDs();
    mInitializeUSBDriver();     // See usbdrv.h
    USBCheckBusStatus();        // Modified to always enable USB module
    while(1)
    {
        USBDriverService();     // See usbdrv.c
        BootService();          // See boot.c
    }//end while
}//end main

#pragma code user = RM_RESET_VECTOR

/** EOF main.c ***************************************************************/
