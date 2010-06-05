/*----------------------------------------------------------------------------------
  SOFTWARE LICENSE AGREEMENT
    1.  Permission to use, copy, modify, and distribute this software
        and its documentation, with or without modification, for any
        purpose and without fee or royalty is hereby granted, provided
        that you include the following on ALL copies of the software
        and documentation or portions thereof, including
        modifications, that you make:

            a.  The full text of this license in a location viewable to users
            of the redistributed or derivative work.

            b.  Notice of any changes or modifications to the files,
            including the date changes were made.

    2.  The name, servicemarks and trademarks of X Engineering
        Software Systems Corp. may NOT be used in advertising or
        publicity pertaining to the software without specific, written
        prior permission.

    3.  Title to copyright in this software and any associated
        documentation will at all times remain with X Engineering
        Software Systems Corp.

    4.  THIS SOFTWARE AND DOCUMENTATION IS PROVIDED "AS IS," AND X
        Engineering Software Systems Corp MAKES NO REPRESENTATIONS OR
        WARRANTIES, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO,
        WARRANTIES OF MERCHANTABILITY OR FITNESS FOR ANY PARTICULAR
        PURPOSE OR THAT THE USE OF THE SOFTWARE OR DOCUMENTATION WILL
        NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS
        OR OTHER RIGHTS.

    5.  X Engineering Software Systems Corp WILL NOT BE LIABLE FOR ANY
        DAMAGES, INCLUDING BUT NOT LIMITED TO, DIRECT, INDIRECT,
        SPECIAL OR CONSEQUENTIAL, ARISING OUT OF ANY USE OF THE
        SOFTWARE OR DOCUMENTATION.

  ©2006 - X Engineering Software Systems Corp.  All rights reserved.
----------------------------------------------------------------------------------*/


#ifndef USBCMD_H
#define USBCMD_H

/**
Definitions of commands sent in USB packets to the XSUSB interface.
*/
typedef enum
{
	/*
	READ_VERSION    		= 0x00,
	READ_FLASH      		= 0x01,
	WRITE_FLASH     		= 0x02,
	ERASE_FLASH     		= 0x03,
	READ_EEDATA     		= 0x04,
	WRITE_EEDATA    		= 0x05,
	READ_CONFIG     		= 0x06,
	WRITE_CONFIG    		= 0x07,
	*/
	ID_BOARD        		= 0x31,
	UPDATE_LED      		= 0x32,
	INFO_CMD				= 0x40,	// Get information about the USB interface.
	SENSE_INVERTERS_CMD		= 0x41,	// Sense inverters on TCK and TDO pins of the secondary JTAG port.
	TMS_TDI_CMD				= 0x42,	// Send a single TMS and TDI bit.
	TMS_TDI_TDO_CMD			= 0x43,	// Send a single TMS and TDI bit and receive TDO bit.
	TDI_TDO_CMD				= 0x44,	// Send multiple TDI bits and receive multiple TDO bits.
	TDO_CMD					= 0x45, // Receive multiple TDO bits.
	TDI_CMD					= 0x46,	// Send multiple TDI bits.
	RUNTEST_CMD				= 0x47,	// Pulse TCK a given number of times.
	NULL_TDI_CMD			= 0x48,	// Send string of TDI bits.
	PROG_CMD				= 0x49,	// Change the level of the FPGA PROGRAM# pin.
	SINGLE_TEST_VECTOR_CMD	= 0x4a,	// Send a single, byte-wide test vector.
	GET_TEST_VECTOR_CMD		= 0x4b,	// Read the current test vector being output.
	SET_OSC_FREQ_CMD		= 0x4c,	// Set the frequency of the DS1075 oscillator. 
	ENABLE_RETURN_CMD		= 0x4d,	// Enable return of info in response to a command.
	DISABLE_RETURN_CMD		= 0x4e,	// Disable return of info in response to a command.
	RESET           		= 0xff
} USBCMD;

#endif
