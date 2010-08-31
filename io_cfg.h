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
//  This module maps pins to their functions.  This provides a layer
//  of abstraction.
//
//********************************************************************

#ifndef IO_CFG_H
#define IO_CFG_H

/** I N C L U D E S *************************************************/
#include "autofiles\usbcfg.h"

/** T R I S *********************************************************/
#define INPUT_PIN           1
#define OUTPUT_PIN          0

/** U S B ***********************************************************/
#define tris_usb_bus_sense  TRISAbits.TRISA1    // Input

#if defined(USE_USB_BUS_SENSE_IO)
#define usb_bus_sense       PORTAbits.RA1
#else
#define usb_bus_sense       1
#endif

#define tris_self_power     TRISAbits.TRISA2    // Input

#if defined(USE_SELF_POWER_SENSE_IO)
#define self_power          PORTAbits.RA2
#else
#define self_power          1
#endif

/** Firmware update jumper sense ************************************/
#define mInitFMWUpdate_b()  LATBbits.LATB7 = 1; TRISBbits.TRISB7 = INPUT_PIN; INTCON2bits.NOT_RABPU = 0;
#define mFMWUpdate_b        PORTBbits.RB7

/** FPGA PROG# pin control ******************************************/
#define mInitProg_b()       LATCbits.LATC3 = 0; TRISCbits.TRISC3 = OUTPUT_PIN;
#define mProg_b             LATCbits.LATC3

/** L E D ***********************************************************/
#define mInitAllLEDs()      LATCbits.LATC5 = 0; TRISCbits.TRISC5 = OUTPUT_PIN;
#define mLED                LATCbits.LATC5
#define mLED_On()           mLED = 1;
#define mLED_Off()          mLED = 0;
#define mLED_Toggle()       mLED = !mLED;

#endif //IO_CFG_H
