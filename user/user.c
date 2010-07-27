//*********************************************************************
// Module Name: user.c
//
// Copyright 2007 X Engineering Software Systems Corp.
// All rights reserved.
//
// Module Description:
// This module manages the interface between the USB port and the JTAG
// ports of the FPGA and CPLD on the XS board.
//
// Revision: $Id$
//********************************************************************


/** I N C L U D E S **********************************************************/

#include <p18cxxx.h>
#include <usart.h>
#include <string.h>
#include <delays.h>
#include "system\typedefs.h"

#include "system\usb\usb.h"

#include "io_cfg.h"             // I/O pin mapping

#include "usbcmd.h"

/** D E F I N I T I O N S ********************************************************/

#define	YES		1
#define	NO		0
#define	TRUE	1
#define	FALSE	0

#define NUM_JTAG_PORTS		1	// The XSUSB interface controls two JTAG ports. 
#define	PRIMARY_JTAG_PORT	0	// Primary JTAG port.  Usually connected to the FPGA.

#define	MIPS					12	// Number of processor instructions per second.

#define MAX_BYTE_VAL			0xFF	// Maximum value that can be stored in a byte.
#define NUM_ACTIVITY_BLINKS		10		// Indicate activity by blinking the LED this many times.
#define BLINK_SCALER			10		// Make larger to stretch the time between LED blinks.

#define	DO_DELAY_THRESHOLD		5461L	// Threshold between pulsing TCK or using a timer = (1000000 / (12000000 / 256))

#define USE_MSSP				YES		// YES if driving JTAG with MSSP block; NO to use bit-banging.

// Pin definitions for connections to JTAG port of device.
// TCK of the JTAG device is driven by the SSP SCK clock.
#define	TCK_TRIS		TRISBbits.TRISB6
#define	TCK_ASM			PORTB,6,ACCESS
#define	TCK				PORTBbits.RB6
#define	TCK_MASK		(0x01<<6)
// TMS of the JTAG device is driven by a general-purpose output.
#define	TMS_TRIS		TRISBbits.TRISB5
#define	TMS_ASM			PORTB,5,ACCESS
#define	TMS				PORTBbits.RB5
#define	TMS_MASK		(0x01<<5)
// TDI of the JTAG device is driven by the MSB of the SSP shift-register.
#define	TDI_TRIS		TRISBbits.TRISB4
#define	TDI_ASM			PORTB,4,ACCESS
#define	TDI				PORTBbits.RB4
#define	TDI_MASK		(0x01<<4)
// TDO from the JTAG device enters into the LSB of the SSP shift-register.
#define	TDO_TRIS		TRISCbits.TRISC7
#define	TDO_ASM			PORTC,7,ACCESS
#define	TDO				PORTCbits.RC7
#define	TDO_MASK		(0x01<<7)
// Output pin that controls the PROG# pin of the FPGA.
#define	PROG_TRIS		TRISCbits.TRISC4
#define	PROG			PORTCbits.RC4

// ALU carry bit.
#define	CARRY_POS		0
#define	CARRY_BIT_ASM	STATUS,CARRY_POS,ACCESS
// MSSP buffer-full bit.
#define	MSSP_BF_POS		0
#define	MSSP_BF_ASM		WREG,MSSP_BF_POS,ACCESS

// Converse of using ACCESS flag for destination register.
#define	TO_WREG			0

/** S T R U C T U R E S ******************************************************/

typedef union DATA_PACKET
{
    byte _byte[USBGEN_EP_SIZE];  	//For byte access
    word _word[USBGEN_EP_SIZE/2];	//For word access(USBGEN_EP_SIZE must be even)
    struct
    {
	    USBCMD cmd;
        byte len;
    };
	struct
	{
	    USBCMD cmd;
		char info_str[USBGEN_EP_SIZE-1];
	};
	struct // TAP_SEQ_CMD structure
	{
	    USBCMD cmd;
		long num_bits;
		byte flags;
	};
	struct
	{
	    USBCMD cmd;
		long num_tck_pulses;
	};
	struct
	{
	    USBCMD cmd;
		unsigned prog:1;
	};
} DATA_PACKET;


// Definitions for TAP_SEQ_CMD

#define TAP_SEQ_CMD_HDR_LEN			    6

// Flag bits
#define GET_TDO_MASK					0x01    // Set if gathering TDO bits.
#define PUT_TMS_MASK					0x02    // Set if TMS bits are included in the packets.
#define TMS_VAL_MASK					0x04    // Static value for TMS if PUT_TMS_MASK is cleared.
#define PUT_TDI_MASK					0x08    // Set if TDI bits are included in the packets.
#define TDI_VAL_MASK					0x10    // Static value for TDI if PUT_TDI_MASK is cleared.
#define	DO_MULTIPLE_PACKETS_MASK		0x80    // Set if command extends over multiple USB packets.


/** V A R I A B L E S ********************************************************/

// This table is used to reverse the bits within a byte.  The table has to be located at
// the beginning of a page because we index into the table by placing the byte value
// whose bits are to be reversed into TBLPTRL without changing TBLPTRH or TBLPTRU.
#pragma romdata reverse_bits_section=0x1F00
static rom const byte reverse_bits[] = {
	0x00, 0x80, 0x40, 0xc0, 0x20, 0xa0, 0x60, 0xe0, 0x10, 0x90, 0x50, 0xd0, 0x30, 0xb0, 0x70, 0xf0, 
	0x08, 0x88, 0x48, 0xc8, 0x28, 0xa8, 0x68, 0xe8, 0x18, 0x98, 0x58, 0xd8, 0x38, 0xb8, 0x78, 0xf8, 
	0x04, 0x84, 0x44, 0xc4, 0x24, 0xa4, 0x64, 0xe4, 0x14, 0x94, 0x54, 0xd4, 0x34, 0xb4, 0x74, 0xf4, 
	0x0c, 0x8c, 0x4c, 0xcc, 0x2c, 0xac, 0x6c, 0xec, 0x1c, 0x9c, 0x5c, 0xdc, 0x3c, 0xbc, 0x7c, 0xfc, 
	0x02, 0x82, 0x42, 0xc2, 0x22, 0xa2, 0x62, 0xe2, 0x12, 0x92, 0x52, 0xd2, 0x32, 0xb2, 0x72, 0xf2, 
	0x0a, 0x8a, 0x4a, 0xca, 0x2a, 0xaa, 0x6a, 0xea, 0x1a, 0x9a, 0x5a, 0xda, 0x3a, 0xba, 0x7a, 0xfa, 
	0x06, 0x86, 0x46, 0xc6, 0x26, 0xa6, 0x66, 0xe6, 0x16, 0x96, 0x56, 0xd6, 0x36, 0xb6, 0x76, 0xf6, 
	0x0e, 0x8e, 0x4e, 0xce, 0x2e, 0xae, 0x6e, 0xee, 0x1e, 0x9e, 0x5e, 0xde, 0x3e, 0xbe, 0x7e, 0xfe, 
	0x01, 0x81, 0x41, 0xc1, 0x21, 0xa1, 0x61, 0xe1, 0x11, 0x91, 0x51, 0xd1, 0x31, 0xb1, 0x71, 0xf1, 
	0x09, 0x89, 0x49, 0xc9, 0x29, 0xa9, 0x69, 0xe9, 0x19, 0x99, 0x59, 0xd9, 0x39, 0xb9, 0x79, 0xf9, 
	0x05, 0x85, 0x45, 0xc5, 0x25, 0xa5, 0x65, 0xe5, 0x15, 0x95, 0x55, 0xd5, 0x35, 0xb5, 0x75, 0xf5, 
	0x0d, 0x8d, 0x4d, 0xcd, 0x2d, 0xad, 0x6d, 0xed, 0x1d, 0x9d, 0x5d, 0xdd, 0x3d, 0xbd, 0x7d, 0xfd, 
	0x03, 0x83, 0x43, 0xc3, 0x23, 0xa3, 0x63, 0xe3, 0x13, 0x93, 0x53, 0xd3, 0x33, 0xb3, 0x73, 0xf3, 
	0x0b, 0x8b, 0x4b, 0xcb, 0x2b, 0xab, 0x6b, 0xeb, 0x1b, 0x9b, 0x5b, 0xdb, 0x3b, 0xbb, 0x7b, 0xfb, 
	0x07, 0x87, 0x47, 0xc7, 0x27, 0xa7, 0x67, 0xe7, 0x17, 0x97, 0x57, 0xd7, 0x37, 0xb7, 0x77, 0xf7, 
	0x0f, 0x8f, 0x4f, 0xcf, 0x2f, 0xaf, 0x6f, 0xef, 0x1f, 0x9f, 0x5f, 0xdf, 0x3f, 0xbf, 0x7f, 0xff, 
};

#pragma romdata
static rom const char *info_str = "V01.05\n"; // Change version in usbdsc.c as well!!

#pragma udata access my_access
near long lcntr;					// Large counter for fast loops.
near byte buffer_cntr;				// Holds the number of bytes left to process in the USB packet.
near word save_FSR0, save_FSR1;		// Used for saving the contents of PIC hardware registers.

#pragma udata
unsigned int timer2;		// Timer for RUNTEST command.
byte blink_counter;			// Holds the number of times to blink the LED.
byte blink_scaler;			// Scaler to reduce blink rate over what can be achieved with only the TIMER2 hardware.
DATA_PACKET dataPacket;		// Holds the current USB data packet.

typedef enum {MICROSECONDS, MILLISECONDS} TimeUnit;

// Structure to hold single and multi-bit flags.
typedef struct USER_FLAGS
{
	unsigned disable_pri_return : 1;	// if true, disable return of any primary JTAG packets.
} USER_FLAGS;
static USER_FLAGS flag;

/** P R I V A T E  P R O T O T Y P E S ***************************************/

void BlinkLED(void);
void ServiceRequests(void);
static void InsertDelay(unsigned int t, TimeUnit u);

/** D E C L A R A T I O N S **************************************************/

#pragma code
void UserInit(void)
{
    // Setup the LED and its blink timer.
    mInitAllLEDs();
    blink_counter   = 0;	// No blinks of the LED, yet.
    T2CON           = 0x7F;	// Enable TIMER2 and set pre-,post-scalers to 16 so it increments once every 65536/12MHz = 5.5 ms.
    PR2             = 255;	// TIMER2 issues interrupt every time it reaches 255.
    RCONbits.IPEN   = 1;	// Enable prioritized interrupts.
    PIR1            = 0;	// Clear all perpheral interrupt flags.
    PIE1bits.TMR2IE = 1;	// Enable TIMER2 interrupt.
    IPR1bits.TMR2IP = 0;	// Make TIMER2 issue a low-priority interrupt.
    INTCONbits.GIEL = 1;	// Enable low-priority interrupts.
    INTCONbits.GIEH = 1;	// Enable high-priority interrupts.

	PROG_TRIS = 0;			// Enable output pin that controls the FPGA PROG# pin.
	PROG = 1;				// Don't erase the FPGA unless specifically requested. 

	TCK_TRIS = 0;			// Enable output to TCK pin of primary JTAG device.
	TMS_TRIS = 0;			// Enable output to TMS pin of primary JTAG device.
	TDI_TRIS = 0;			// Enable output to TDI pin of primary JTAG device.
	TDO_TRIS = 1;			// Enable input from TDO pin of primary JTAG device.

	// Setup the Master Synchronous Serial Port in SPI mode.
	PIE1bits.SSPIE      = 0;	// Disable SSP interrupts.
	SSPCON1bits.SSPEN	= 0;	// Disable the SSP until it's needed.
	SSPSTATbits.SMP		= 0;	// Sample TDO on the rising clock edge.  (TDO changes on the falling clock edge.)
	SSPSTATbits.CKE		= 1;	// Change the bit output to TDI on the falling clock edge. (TDI is sampled on rising clock edge.)
	SSPCON1bits.CKP		= 0;	// Make the clock's idle state be the low logic level (logic 0).
	SSPCON1bits.SSPM0	= 0;	// Set the SSP into SPI master mode with clock = Fosc/4 (fastest setting).
	SSPCON1bits.SSPM1	= 0;	//    MUST STAY AT THIS SETTING BECAUSE WE ASSUME BYTE TRANSMISSION
	SSPCON1bits.SSPM2	= 0;	//    TAKES 8 INSTRUCTION CYCLES IN THE TDI, TDO LOOPS BELOW!!!
	SSPCON1bits.SSPM3	= 0;

	flag.disable_pri_return = 0;

}//end UserInit


/******************************************************************************
 * Function:        void ProcessIO(void)
 *
 * PreCondition:    None
 *
 * Input:           None
 *
 * Output:          None
 *
 * Side Effects:    None
 *
 * Overview:        This function is a place holder for other user routines.
 *                  It is a mixture of both USB and non-USB tasks.
 *
 * Note:            None
 *****************************************************************************/
void ProcessIO(void)
{   
    // User Application USB tasks
    if((usb_device_state < CONFIGURED_STATE)||(UCONbits.SUSPND==1U))
        return;
    ServiceRequests();
}//end ProcessIO

void ServiceRequests(void)
{
	byte num_return_bytes;			// Number of bytes to return in response to received command.
	byte* tdi_data[2];				// Pointers to USB ping-pong endpoint buffers containing TDI bits.
	byte* tdo_data[2];				// Pointers to USB ping-pong endpoint buffers containing TDO bits.
	byte data_index;				// Index of the currently-active endpoint data buffer.
	byte *tdi;						// Pointers to the currently-active endpoint buffer for TDI bits.
	byte *tdo;						// Pointers to the currently-active endpoint buffer for TDO bits.
	byte *tms_tdi;					// Pointers to the currently-active endpoint buffer for TDI & TMS bits.
	long num_bits;					// # of total bits in stream of bits sent to and from the JTAG device.
	byte num_final_bits;			// # of bits in the final packet of TDI/TDO bits.
	long num_bytes;					// # of total bytes in the stream of TDI/TDO bits.
	byte num_final_bytes;			// # of bytes in the final packet of TDI/TDO bits.
	byte hdr_size;
	byte flags;
	byte bit_mask;					// Mask to select bit from a byte.
	byte bit_cntr;					// Counter within a byte of bits.
	byte tms_byte, tdi_byte, tdo_byte;		// Temporary bytes of TMS, TDI and TDO bits.
	static byte use_mssp = USE_MSSP;	// True if MSSP is used to drive JTAG pins; false if bit-banging is used.

	num_return_bytes = 0;	// Initially, assume nothing needs to be returned.
	
	// Process packets received through the primary endpoint.
    if(USBGenPrimaryRead((byte*)&dataPacket,sizeof(dataPacket)))
    {
        USBDriverService();                 // Interrupt or polling method
		
		blink_counter = NUM_ACTIVITY_BLINKS;	// Blink the LED whenever a USB transaction occurs.
		
        switch(dataPacket.cmd)	// Process the contents of the packet based on the command byte.
        {
            case ID_BOARD:
            	// Blink the LED in order to identify the board.
                blink_counter = 50;
                num_return_bytes = 1;
                break;

            case INFO_CMD:
				// Return a packet with information about this USB interface device.
				strcpypgm2ram(dataPacket.info_str, info_str);
                num_return_bytes=sizeof(dataPacket);	// Return information stored in packet.
                break;

			case TAP_SEQ_CMD:		// Output TMS & TDI values; get TDO value 
				num_return_bytes = 0;	// This command doesn't return any bytes by the default return routine.

				blink_counter = MAX_BYTE_VAL;	// Blink LED continuously during the (long) duration of this command.

				// The first packet received contains the TAP_SEQ_CMD command and the number
				// of TDI bits that will follow in succeeding packets.
				num_bits = dataPacket.num_bits;

				// Exit if no TDI bits will follow (this is probably an error...).
				if(num_bits == 0)
					break;

				// Get flags from the first packet that indicate how TMS and TDO bits are handled.
				flags = dataPacket.flags;

				// Setup pointers to the ping-pong buffers for getting/returning TDI/TDO bits.
				tdi_data[0] = usbgen_primary_out0;
				tdi_data[1] = usbgen_primary_out1;
				tdo_data[0] = usbgen_primary_in0;
				tdo_data[1] = usbgen_primary_in1;
				data_index  = 1;  // Index to the active ping-pong buffers.

				hdr_size = TAP_SEQ_CMD_HDR_LEN;  // Size of the command header in the first packet.
				tms_tdi  = (byte*)&dataPacket + hdr_size;  // Pointer to TMS+TDI bits that follow command bytes in first packet.
				tdo      = tdo_data[data_index];  // Pointer to buffer for storing TDO bits.

				// Total number of header+TMS+TDI bytes in all the packets for this command.
				num_bytes = (long)((num_bits+7)/8);
				if(flags & PUT_TMS_MASK)
					num_bytes *= 2; // Twice the number of bytes if TMS bits are also being sent.
				num_bytes += hdr_size;

                // Initialize TCK, TMS and TDI levels.
				TCK = 0;  // Initialize TCK (should have been low already).
				if(!(flags & PUT_TMS_MASK))
					TMS = (flags & TMS_VAL_MASK) ? 1:0; // No TMS bits in packets, so set TMS to the static value indicated in the flag bit.
				if(!(flags & PUT_TDI_MASK))
					TDI = (flags & TDI_VAL_MASK) ? 1:0; // No TDI bits in packets, so set TDI to the static value indicated in the flag bit.

				// Process the first M-1 of M packets that are completely filled with TMS+TDI bits.
				flags &= ~DO_MULTIPLE_PACKETS_MASK; // Assume this command uses a single USB packet.
				for( ; num_bytes > USBGEN_EP_SIZE; num_bytes-=USBGEN_EP_SIZE)
				{
					flags |= DO_MULTIPLE_PACKETS_MASK;	// Record that this command extends over multiple USB packets.

					if(blink_counter == 0U)
						blink_counter = MAX_BYTE_VAL;	// Keep LED blinking during this command to indicate activity.

					// Process the TMS & TDI bytes in the packet and collect the TDO bits.
					switch(flags & (PUT_TDI_MASK | PUT_TMS_MASK | GET_TDO_MASK))
					{
                        case GET_TDO_MASK:  // Just gather TDO bits
                            if(use_mssp)
                            {
                                tdi_byte = (flags & TDI_VAL_MASK) ? 0xFF : 0x00;
            					TCK_TRIS = 1;	// Disable the TCK output so that the clock won't glitch when the MSSP is enabled.
            					SSPCON1bits.SSPEN = 1;	// Enable the MSSP.
            					TCK_TRIS = 0;	// Enable the TCK output after the MSSP glitch is over.
             					buffer_cntr = USBGEN_EP_SIZE - hdr_size;
            					save_FSR0 = FSR0;
            					save_FSR1 = FSR1;
        						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
        						FSR0 = (word)tdo;
    							_asm
    							MOVLW	0						// Load the SPI transmitter with 0's
    							MOVWF	SSPBUF,ACCESS			//   so TDI is cleared while TDO is collected.
    							NOP								// The NOPs are used to insert delay while the SSPBUF is tx/rx'ed.
    							NOP
    							NOP
    							NOP
    							NOP
    							NOP
    						PRI_TAP_LOOP_2:
    							NOP
    							NOP
    							DCFSNZ	buffer_cntr,1,ACCESS
    							BRA		PRI_TAP_LOOP_3
    							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
    							MOVWF	SSPBUF,ACCESS
    							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
    							MOVFF	TABLAT,POSTINC0			// Store the TDO byte into the buffer and inc. the pointer.
    							BRA		PRI_TAP_LOOP_2
    						PRI_TAP_LOOP_3:
    							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
    							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
    							MOVFF	TABLAT,POSTINC0			// Store the TDO byte into the buffer and inc. the pointer.
    							_endasm
            					TCK = 0;
            					SSPCON1bits.SSPEN = 0;	// Turn off the MSSP.  The remaining bits are received manually.
            					FSR0 = save_FSR0;
            					FSR1 = save_FSR1;
                            }
                            else
                            {
    							for(buffer_cntr=USBGEN_EP_SIZE-hdr_size ; buffer_cntr!=0; buffer_cntr--)
    							{
    								tdo_byte = 0; // Clear byte for receiving TDO bits.
    								for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
    								{
    									if(TDO)
    										tdo_byte |= bit_mask;
    									TCK = 1;
    									TCK = 0;
    								}
    								*tdo++ = tdo_byte; // Store received TDO bits into the outgoing packet.
    							}
                            }
                            break;
						case PUT_TDI_MASK:	// Just output the TDI bits.
       						if(use_mssp)
    						{
            					TCK_TRIS = 1;	// Disable the TCK output so that the clock won't glitch when the MSSP is enabled.
            					SSPCON1bits.SSPEN = 1;	// Enable the MSSP.
            					TCK_TRIS = 0;	// Enable the TCK output after the MSSP glitch is over.
             					buffer_cntr = USBGEN_EP_SIZE - hdr_size;
            					save_FSR0 = FSR0;
            					save_FSR1 = FSR1;
        						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
        						FSR0 = (word)tms_tdi;
    							_asm
    							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
    							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
    							MOVFF	TABLAT,SSPBUF			// Load TDI byte into SPI transmitter.
    							NOP
    							NOP
    						PRI_TAP_LOOP_0:
    							DCFSNZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue if not zero
    							BRA		PRI_TAP_LOOP_1
    							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
    							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
    							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte just to clear the buffer-full flag (don't use TDO).
    							MOVFF	TABLAT,SSPBUF			// Load TDI byte into SPI transmitter ASAP.
    							BRA		PRI_TAP_LOOP_0
    						PRI_TAP_LOOP_1:
    							NOP
    							NOP
    							NOP
    							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte just to clear the buffer-full flag (don't use TDO).
    							_endasm
            					TCK = 0;
            					SSPCON1bits.SSPEN = 0;	// Turn off the MSSP.  The remaining bits are transmitted manually.
            					FSR0 = save_FSR0;
            					FSR1 = save_FSR1;
    						}
                            else
                            {
    							for(buffer_cntr=USBGEN_EP_SIZE-hdr_size ; buffer_cntr!=0; buffer_cntr--)
    							{
    								tdi_byte = *tms_tdi++;
    								for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
    								{
    									TDI = tdi_byte & bit_mask ? 1:0;
    									TCK = 1;
    									TCK = 0;
    								}
    							}
                            }
							break;
						case PUT_TDI_MASK | GET_TDO_MASK:	// Output only TDI bits while collecting TDO bits.
							for(buffer_cntr=USBGEN_EP_SIZE-hdr_size ; buffer_cntr!=0; buffer_cntr--)
							{
								tdi_byte = *tms_tdi++;
								tdo_byte = 0; // Clear byte for receiving TDO bits.
								for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
								{
									if(TDO)
										tdo_byte |= bit_mask;
									TDI = tdi_byte & bit_mask ? 1:0;
									TCK = 1;
									TCK = 0;
								}
								*tdo++ = tdo_byte; // Store received TDO bits into the outgoing packet.
							}
							break;
						case PUT_TDI_MASK | PUT_TMS_MASK:	// Output both TDI & TMS bits and ignore TDO bits.
							for(buffer_cntr=USBGEN_EP_SIZE-hdr_size ; buffer_cntr!=0; buffer_cntr-=2)
							{
								tms_byte = *tms_tdi++;
								tdi_byte = *tms_tdi++;
								for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
								{
									TMS = tms_byte & bit_mask ? 1:0;
									TDI = tdi_byte & bit_mask ? 1:0;
									TCK = 1;
									TCK = 0;
								}
							}
							break;
						case PUT_TDI_MASK | PUT_TMS_MASK | GET_TDO_MASK:	// Output both TDI & TMS bits while collecting TDO bits.
						default:
							for(buffer_cntr=USBGEN_EP_SIZE-hdr_size ; buffer_cntr!=0; buffer_cntr-=2)
							{
								tms_byte = *tms_tdi++;
								tdi_byte = *tms_tdi++;
								tdo_byte = 0; // Clear byte for receiving TDO bits.
								for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
								{
									if(TDO)
										tdo_byte |= bit_mask;
									TMS = tms_byte & bit_mask ? 1:0;
									TDI = tdi_byte & bit_mask ? 1:0;
									TCK = 1;
									TCK = 0;
								}
								*tdo++ = tdo_byte; // Store received TDO bits into the outgoing packet.
							}
							break;
					}

					// Send all the recorded TDO bits back in a complete packet.
					if(flags & GET_TDO_MASK)
					{
	       				while(mUSBGenPrimaryTxIsBusy()) ;  // Wait until USB transmitter is not busy.
						USBGEN_BD_PRIMARY_IN.ADR = tdo_data[data_index];  // Set endpoint pointer to stored TDO bit buffer.
                        // If received packets contain both TDI & TMS bits, return TDO packet is half-size (one TDO bit per TDI bit).
						if(flags & PUT_TMS_MASK)
					    	USBGEN_BD_PRIMARY_IN.Cnt = (USBGEN_EP_SIZE-hdr_size) / 2;
						else
					    	USBGEN_BD_PRIMARY_IN.Cnt = (USBGEN_EP_SIZE-hdr_size);
						USBDriverService();
				    	mUSBBufferReady(USBGEN_BD_PRIMARY_IN);
					}

                    if(flags & PUT_TDI_MASK)
                    {
    					// Wait until the next packet of TMS & TDI bits arrives.
    					while(mUSBGenPrimaryRxIsBusy()) ;
    
    					// Change the buffer address in the endpoint so it will place the next packet of TDI bits
    					// in the other ping-pong buffer while the current TDI packet is sent to the JTAG port.
    					if(num_bytes-USBGEN_EP_SIZE > USBGEN_EP_SIZE)
    					{
    						USBGEN_BD_PRIMARY_OUT.ADR = tdi_data[data_index];	// Change buffer address in endpoint.
    			        	USBGEN_BD_PRIMARY_OUT.Cnt = USBGEN_EP_SIZE;
    	     				mUSBBufferReady(USBGEN_BD_PRIMARY_OUT);		// Enable the endpoint to receive more TMS & TDI data.
    					    USBDriverService();
    					}
                    }

					data_index ^= 1;  // Point to the next ping-pong buffer.
					tms_tdi     = tdi_data[data_index];  // Init pointer to the just-received TMS & TDI data.
					tdo         = tdo_data[data_index];  // TDO data will be written here.

					hdr_size = 0;  // There is no command header in any packets following the first, just TDI & TMS bits.
				}  // First M-1 TDI packets have been processed.

                // If only one packet was received, this will subtract the number of command header bytes.
                // Otherwise, the number of bytes is just the number in the last packet.
				num_bytes -= hdr_size;

				// Process all except the last TDI byte in the final packet.
				switch(flags & (PUT_TDI_MASK | PUT_TMS_MASK | GET_TDO_MASK))
				{
                    case GET_TDO_MASK:  // Just gather TDO bits
						for(buffer_cntr=num_bytes; buffer_cntr>1; buffer_cntr--)
						{
							tdo_byte = 0; // Clear byte for receiving TDO bits.
							for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
							{
								if(TDO)
									tdo_byte |= bit_mask;
								TCK = 1;
								TCK = 0;
							}
							*tdo++ = tdo_byte; // Store received TDO bits into the outgoing packet.
						}
                        break;
					case PUT_TDI_MASK:	// Just output the TDI bits.
						for(buffer_cntr=num_bytes; buffer_cntr>1; buffer_cntr--)
						{
							tdi_byte = *tms_tdi++;
							for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
							{
								TDI = tdi_byte & bit_mask ? 1:0;
								TCK = 1;
								TCK = 0;
							}
						}
						break;
					case PUT_TDI_MASK | GET_TDO_MASK:	// Output only TDI bits while collecting TDO bits.
						for(buffer_cntr=num_bytes; buffer_cntr>1; buffer_cntr--)
						{
							tdi_byte = *tms_tdi++;
							tdo_byte = 0; // Clear byte for receiving TDO bits.
							for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
							{
								if(TDO)
									tdo_byte |= bit_mask;
								TDI = tdi_byte & bit_mask ? 1:0;
								TCK = 1;
								TCK = 0;
							}
							*tdo++ = tdo_byte; // Store received TDO bits into the outgoing packet.
						}
						break;
					case PUT_TDI_MASK | PUT_TMS_MASK:	// Output both TDI & TMS bits and ignore TDO bits.
						for(buffer_cntr=num_bytes; buffer_cntr>2; buffer_cntr-=2)
						{
							tms_byte = *tms_tdi++;
							tdi_byte = *tms_tdi++;
							for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
							{
								TMS = tms_byte & bit_mask ? 1:0;
								TDI = tdi_byte & bit_mask ? 1:0;
								TCK = 1;
								TCK = 0;
							}
						}
						break;
					case PUT_TDI_MASK | PUT_TMS_MASK | GET_TDO_MASK:	// Output both TDI & TMS bits while collecting TDO bits.
					default:
						for(buffer_cntr=num_bytes; buffer_cntr>2; buffer_cntr-=2)
						{
							tms_byte = *tms_tdi++;
							tdi_byte = *tms_tdi++;
							tdo_byte = 0; // Clear byte for receiving TDO bits.
							for(bit_cntr=8, bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
							{
								if(TDO)
									tdo_byte |= bit_mask;
								TMS = tms_byte & bit_mask ? 1:0;
								TDI = tdi_byte & bit_mask ? 1:0;
								TCK = 1;
								TCK = 0;
							}
							*tdo++ = tdo_byte; // Store received TDO bits into the outgoing packet.
						}
						break;
				}

				// Send the last few bits of the last byte of TDI bits.
				// Compute the number of bits in the final byte of the final packet.
				// (This computation only works because num_bits != 0.)
				bit_cntr = num_bits & 0x7;
				if(bit_cntr==0U)
					bit_cntr = 8U;

				// Read last TMS & TDI bytes from the packet and transmit them.
				if(flags & PUT_TMS_MASK)
					tms_byte = *tms_tdi++;
                if(flags & PUT_TDI_MASK)
                    tdi_byte = *tms_tdi;
                else
                    tdi_byte = (flags & TDI_VAL_MASK) ? 0xFF : 0x00;
				tdo_byte = 0; // Clear byte for receiving last TDO bits.
				for(bit_mask=0x01; bit_cntr!=0; bit_cntr--, bit_mask<<=1)
				{
					if(TDO)
						tdo_byte |= bit_mask;
					if(flags & PUT_TMS_MASK)
						TMS = tms_byte & bit_mask ? 1:0;
					TDI = tdi_byte & bit_mask ? 1:0;
					TCK = 1;
					TCK = 0;
				}

				// Send back the final packet of TDO bits.
				if(flags & GET_TDO_MASK)
				{
					*tdo = tdo_byte; // Store last few TDO bits into the outgoing packet.
       				while(mUSBGenPrimaryTxIsBusy()) ;  // Wait until USB transmitter is not busy.
					USBGEN_BD_PRIMARY_IN.ADR = tdo_data[data_index];
                    // If received packets contain both TDI & TMS bits, return TDO packet is half-size (one TDO bit per TDI bit).
					if(flags & PUT_TMS_MASK)
					   	USBGEN_BD_PRIMARY_IN.Cnt = num_bytes / 2;
					else
					   	USBGEN_BD_PRIMARY_IN.Cnt = num_bytes;
					USBDriverService();
				    mUSBBufferReady(USBGEN_BD_PRIMARY_IN);
				}
				
				if((flags & DO_MULTIPLE_PACKETS_MASK) && (flags & PUT_TDI_MASK))
				{
					// We have received the last TDI byte in a multi-packet transmission,
					// so reset the endpoint to the default buffer and re-enable the endpoint.
					USBGEN_BD_PRIMARY_OUT.ADR = usbgen_primary_out0;
			        USBGEN_BD_PRIMARY_OUT.Cnt = USBGEN_EP_SIZE;
					mUSBBufferReady(USBGEN_BD_PRIMARY_OUT);
				}
				
				// Blink the LED a few times after a long command completes.
				if(blink_counter < MAX_BYTE_VAL-NUM_ACTIVITY_BLINKS)
					blink_counter = 0;	// Already done enough LED blinks.
				else
					blink_counter -= (MAX_BYTE_VAL-NUM_ACTIVITY_BLINKS);	// Do at least the minimum number of blinks.

				break;

			case RUNTEST_CMD:
				if(dataPacket.num_tck_pulses > DO_DELAY_THRESHOLD)
				{
					// For RUNTEST with large number of TCK pulses, just use a timer.
					timer2 = 1 + dataPacket.num_tck_pulses / DO_DELAY_THRESHOLD;	// Set timer for needed time delay.
					while(timer2)
						;	// Timer is decremented by the timer interrupt routine.
				}
				else
				{
					// For RUNTEST with a smaller number of TCK pulses, actually pulse the TCK pin.
					for(lcntr = dataPacket.num_tck_pulses; lcntr!=0; lcntr--)
					{
						TCK ^= 1;
						TCK ^= 1;
					}
				}
				num_return_bytes = 5; // return the entire command as an acknowledgement
                break;
				
			case PROG_CMD:
				PROG = dataPacket.prog;
				num_return_bytes = 0;			// Don't return any acknowledgement.
				break;

            case RESET:
                Reset();
                break;
                
            default:
				num_return_bytes = 0;
                break;
        }//end switch()

		// Packets of data are returned to the PC here.
		// The counter indicates the number of data bytes in the outgoing packet.
        if(num_return_bytes != 0U)
        {
			while(mUSBGenPrimaryTxIsBusy()); // Wait until transmitter is not busy.
            USBGenPrimaryWrite((byte*)&dataPacket,num_return_bytes); // Now send the packet.
        }//end if
    }//end if

}//end ServiceRequests

/******************************************************************************
 * Function:        void InsertDelay(unsigned int t, TimeUnit u)
 *
 * PreCondition:    None
 *
 * Input:           t - number of time units
 *                  u - time unit
 *
 * Output:          None
 *
 * Side Effects:    None
 *
 * Overview:        Inserts a delay t of time units u.
 *****************************************************************************/

static void InsertDelay(unsigned int t, TimeUnit u)
{
	unsigned int i;
	unsigned int cycles;
	switch(u)
	{
		case MICROSECONDS:
			cycles = t * MIPS;
			if(cycles < 10U)
				;
			else if(cycles < 10U*0xFFU)
				Delay10TCYx(cycles / 10U);
			else if(cycles < 100U*0xFFU)
				Delay100TCYx(cycles / 100U);
			else
				Delay1KTCYx(cycles / 1000U);
			break;
		case MILLISECONDS:
			for(i=0; i<t; i++)
				InsertDelay(1000U,MICROSECONDS);
			break;
		default:
			break;
	}
}

/******************************************************************************
 * Function:        void BlinkLED(void)
 *
 * PreCondition:    None
 *
 * Input:           None
 *
 * Output:          None
 *
 * Side Effects:    None
 *
 * Overview:        BlinkLED turns on and off an LED if the number of blinks is greater
 *					than zero and the USB is CONFIGURED.
 *
 * Note:            LED macros are in io_cfg.h
 *                  usb_device_state is declared in usbmmap.c and is modified
 *                  in usbdrv.c, usbctrltrf.c, and usb9.c
 *****************************************************************************/
#pragma interruptlow BlinkLED
void BlinkLED(void)
{
	PIR1bits.TMR2IF = 0;	// Clear the timer interrupt flag.
	
	timer2--;

	// Decrement the scaler and reload it when it reaches zero.
    if(blink_scaler == 0U)
    	blink_scaler = BLINK_SCALER;
    blink_scaler--;
    
    if(usb_device_state < ADDRESS_STATE)
    {	// Turn off the LED if the USB device has not linked with the PC yet.
	    mLED_Off();
	}
	else
	{	// The USB device has linked with the PC, so activate the LED.
		if(blink_scaler==0U)
		{	// Only update the LED state when the scaler reaches zero.
			if(blink_counter>0U)
			{	// Toggle the LED as long as the blink counter is non-zero.
				mLED_Toggle();
				blink_counter--;
			}
			else
			{	// Make sure the LED is left on after the blinking is done.
				mLED_On();
			}
		}
	}
}//end BlinkLED

/** EOF user.c ***************************************************************/
