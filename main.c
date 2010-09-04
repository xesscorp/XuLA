//*********************************************************************
// Copyright (C) 2010 Dave Vanden Bout / XESS Corp. / www.xess.com
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or (at
// your option) any later version.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License along
// with this program; if not, write to the Free Software Foundation, Inc.,
// 51 Franklin St, Fifth Floor, Boston, MA 02110, USA
//
//====================================================================
//
// Module Description:
//  This module boots up the USB-to-JTAG firmware.  Look in user.c
//  for the code that does the majority of the work.
//
//********************************************************************

#include <p18cxxx.h>
#include "system\typedefs.h"                        // Required
#include "system\usb\usb.h"                         // Required
#include "io_cfg.h"                                 // Required

#include "system\usb\usb_compile_time_validation.h" // Optional
#include "user\user.h"                              // Modifiable

static void InitializeSystem(void);
void USBTasks(void);


/** V E C T O R  R E M A P P I N G *******************************************/

extern void _startup (void);        // See c018i.c in your C18 compiler dir
#pragma code _RESET_INTERRUPT_VECTOR = 0x000800
void _reset (void)
{
    _asm goto _startup _endasm
}

#pragma code _HIGH_INTERRUPT_VECTOR = 0x000808
void _high_ISR (void)
{
    ;
}

void BlinkLED(void);
#pragma code _LOW_INTERRUPT_VECTOR = 0x000818
void _low_ISR (void)
{
	{
		_asm
		goto BlinkLED
		_endasm
	}
}


#pragma code

void main(void)
{
    InitializeSystem();
    while(1)
    {
        USBTasks();         // USB Tasks
        ProcessIO();        // See user\user.c & .h
    }
}


static void InitializeSystem(void)
{
    DEFAULT_IO_CFG();
    
    #if defined(USE_USB_BUS_SENSE_IO)
    tris_usb_bus_sense = INPUT_PIN; // See io_cfg.h
    #endif
    
    #if defined(USE_SELF_POWER_SENSE_IO)
    tris_self_power = INPUT_PIN;
    #endif
    
    mInitializeUSBDriver();         // See usbdrv.h
    UserInit();                     // See user.c & .h
}


void USBTasks(void)
{
    USBCheckBusStatus();                    // Must use polling method
    if(UCFGbits.UTEYE!=1U)
        USBDriverService();                 // Interrupt or polling method
}
