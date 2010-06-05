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

#define NUM_JTAG_PORTS		2	// The XSUSB interface controls two JTAG ports. 
#define	PRIMARY_JTAG_PORT	0	// Primary JTAG port.  Usually connected to the FPGA.
#define	SECONDARY_JTAG_PORT	1	// Secondary JTAG port.  Usually connected to the interface CPLD.

#define	MIPS					12	// Number of processor instructions per second.

#define MAX_BYTE_VAL			0xFF	// Maximum value that can be stored in a byte.
#define NUM_ACTIVITY_BLINKS		10		// Indicate activity by blinking the LED this many times.
#define BLINK_SCALER			10		// Make larger to stretch the time between LED blinks.

#define	DO_DELAY_THRESHOLD		5461L	// Threshold between pulsing TCK or using a timer = (1000000 / (12000000 / 256))

#define USE_MSSP				YES		// YES if driving JTAG with MSSP block; NO to use bit-banging.

// Pin definitions for connections to JTAG port of device.
// TCK of the JTAG device is driven by the SSP SCK clock.
#define	TCK_TRIS		TRISBbits.TRISB1
#define	TCK_ASM			PORTB,1,ACCESS
#define	TCK				PORTBbits.RB1
#define	TCK_MASK		(0x01<<1)
// TMS of the JTAG device is driven by a general-purpose output.
#define	TMS_TRIS		TRISDbits.TRISD4
#define	TMS_ASM			PORTD,4,ACCESS
#define	TMS				PORTDbits.RD4
#define	TMS_MASK		(0x01<<4)
// TDI of the JTAG device is driven by the MSB of the SSP shift-register.
#define	TDI_TRIS		TRISCbits.TRISC7
#define	TDI_ASM			PORTC,7,ACCESS
#define	TDI				PORTCbits.RC7
#define	TDI_MASK		(0x01<<7)
// TDO from the JTAG device enters into the LSB of the SSP shift-register.
#define	TDO_TRIS		TRISBbits.TRISB0
#define	TDO_ASM			PORTB,0,ACCESS
#define	TDO				PORTBbits.RB0
#define	TDO_MASK		(0x01<<0)
// Secondary TCK of the JTAG device is driven by a general-purpose output.
#define	SEC_TCK_TRIS	TRISAbits.TRISA5
#define	SEC_TCK_ASM		PORTA,5,ACCESS
#define	SEC_TCK			PORTAbits.RA5
#define	SEC_TCK_MASK	(0x01<<5)
// Secondary TMS of the JTAG device is driven by a general-purpose output.
#define	SEC_TMS_TRIS	TRISBbits.TRISB2
#define	SEC_TMS_ASM		PORTB,2,ACCESS
#define	SEC_TMS			PORTBbits.RB2
#define	SEC_TMS_MASK	(0x01<<2)
// Secondary TDI of the JTAG device is driven by a general-purpose output.
#define	SEC_TDI_TRIS	TRISBbits.TRISB3
#define	SEC_TDI_ASM		PORTB,3,ACCESS
#define	SEC_TDI			PORTBbits.RB3
#define	SEC_TDI_MASK	(0x01<<3)
// Secondary TDO from the JTAG device enters into a general-purpose input.
#define	SEC_TDO_TRIS	TRISAbits.TRISA3
#define	SEC_TDO_ASM		PORTA,3,ACCESS
#define	SEC_TDO			PORTAbits.RA3
#define	SEC_TDO_MASK	(0x01<<3)
// Output pin that enables test vector clock
#define	ENABLE_TEST_VECTOR_TRIS	TRISBbits.TRISB4
#define	ENABLE_TEST_VECTOR	PORTBbits.RB4
// Output pin that controls the PROG# pin of the FPGA.
#define	PROG_TRIS		TRISAbits.TRISA0
#define	PROG			PORTAbits.RA0
// Output pins that control the parallel port data pins.
// (Some of these are already defined above for other functions.)
#define	PPD0_TRIS		TRISCbits.TRISC7
#define	PPD0_ASM		PORTC,7,ACCESS
#define	PPD0			PORTCbits.RC7
#define	PPD0_MASK		(0x01<<7)
#define	PPD1_TRIS		TRISBbits.TRISB1
#define	PPD1_ASM		PORTB,1,ACCESS
#define	PPD1			PORTBbits.RB1
#define	PPD1_MASK		(0x01<<1)
#define	PPD2_TRIS		TRISDbits.TRISD4
#define	PPD2_ASM		PORTD,4,ACCESS
#define	PPD2			PORTDbits.RD4
#define	PPD2_MASK		(0x01<<4)
#define	PPD3_TRIS		TRISDbits.TRISD5
#define	PPD3_ASM		PORTD,5,ACCESS
#define	PPD3			PORTDbits.RD5
#define	PPD3_MASK		(0x01<<5)
#define	PPD4_TRIS		TRISDbits.TRISD6
#define	PPD4_ASM		PORTD,6,ACCESS
#define	PPD4			PORTDbits.RD6
#define	PPD4_MASK		(0x01<<6)
#define	PPD5_TRIS		TRISDbits.TRISD7
#define	PPD5_ASM		PORTD,7,ACCESS
#define	PPD5			PORTDbits.RD7
#define	PPD5_MASK		(0x01<<7)
#define	PPD6_TRIS		TRISBbits.TRISB4
#define	PPD6_ASM		PORTB,4,ACCESS
#define	PPD6			PORTBbits.RB4
#define	PPD6_MASK		(0x01<<4)
#define	PPD7_TRIS		TRISAbits.TRISA0
#define	PPD7_ASM		PORTA,0,ACCESS
#define	PPD7			PORTAbits.RA0
#define	PPD7_MASK		(0x01<<0)
// Output pin that controls the DS1075 programmable oscillator of the XSA-50/100.
#define	PPC0_TRIS		TRISEbits.TRISE0
#define	PPC0_ASM		PORTE,0,ACCESS
#define	PPC0			PORTEbits.RE0
#define	PPC0_MASK		(0x01<<0)

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
	    byte mask;
	    byte test_vector;
	};
	struct
	{
	    USBCMD cmd;
		word div;
		byte extOscPresent;
		byte status;		
	};
	struct
	{
	    USBCMD cmd;
		unsigned tms:1;
		unsigned tdi:1;
		unsigned tdo:1;
		unsigned :5;
	};
	struct
	{
	    USBCMD cmd;
		char info_str[USBGEN_EP_SIZE-1];
	};
	struct
	{
	    USBCMD cmd;
		long num_bits;
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

/** V A R I A B L E S ********************************************************/

// This table is used to reverse the bits within a byte.  The table has to be located at
// the beginning of a page because we index into the table by placing the byte value
// whose bits are to be reversed into TBLPTRL without changing TBLPTRH or TBLPTRU.
#pragma romdata reverse_bits_section=0x1000
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
static rom const char *info_str = "V01.01\n"; // Change version in usbdsc.c as well!!

#pragma udata access my_access
near long lcntr;					// Large counter for fast loops.
near byte buffer_cntr;				// Holds the number of bytes left to process in the USB packet.
near word save_FSR0, save_FSR1;		// Used for saving the contents of PIC hardware registers.
near byte sec_tdo_inv_mask;			// Mask used to invert the TDO bits before returning them to the host.

#pragma udata
unsigned int timer2;		// Timer for RUNTEST command.
byte blink_counter;			// Holds the number of times to blink the LED.
byte blink_scaler;			// Scaler to reduce blink rate over what can be achieved with only the TIMER2 hardware.
DATA_PACKET dataPacket;		// Holds the current USB data packet.
byte curr_test_vector;		// Holds the current test vector being output to the FPGA.

typedef enum {MICROSECONDS, MILLISECONDS} TimeUnit;

// Structure to hold single and multi-bit flags.
typedef struct USER_FLAGS
{
	unsigned disable_pri_return : 1;	// if true, disable return of any primary JTAG packets.
	unsigned disable_sec_return : 1;	// if true, disable return of any secondary JTAG packets.
} USER_FLAGS;
static USER_FLAGS flag;

/** P R I V A T E  P R O T O T Y P E S ***************************************/

void BlinkLED(void);
void ServiceRequests(void);
static void InsertDelay(unsigned int t, TimeUnit u);
static void OutputTestVector(byte tv, byte mask);
static char SenseSecondaryInverters(byte *tck_inv, byte *tdo_inv);
static BOOL SetOscFrequency(int div, BOOL extOscPresent);
static void IssueOscCmd(unsigned int cmd);

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

	// Enable outputs to the parallel port data pins on the board.
	PPD0_TRIS = 0;
	PPD1_TRIS = 0;
	PPD2_TRIS = 0;
	PPD3_TRIS = 0;
	PPD4_TRIS = 0;
	PPD5_TRIS = 0;
	PPD6_TRIS = 0;
	PPD7_TRIS = 0;
	PPD0 = 1;
	
	// Enable output to the DS1075 config. pin.
	PPC0_TRIS = 0;
	PPC0 = 1; 
	
	ENABLE_TEST_VECTOR_TRIS = 0;	// Enable output that controls the loading of test vectors.
	ENABLE_TEST_VECTOR = 0;			// Don't enable test vector loading until specifically called for.
	curr_test_vector = 0x00;		// should we use OutputTestVector(0,0xFF) instead???
	
	PROG_TRIS = 0;			// Enable output pin that controls the FPGA PROG# pin.
	PROG = 1;				// Don't erase the FPGA unless specifically requested. 

	TCK_TRIS = 0;			// Enable output to TCK pin of primary JTAG device.
	TMS_TRIS = 0;			// Enable output to TMS pin of primary JTAG device.
	TDI_TRIS = 0;			// Enable output to TDI pin of primary JTAG device.
	TDO_TRIS = 1;			// Enable input from TDO pin of primary JTAG device.
	
	SEC_TCK_TRIS = 0;		// Enable output to TCK pin of secondary JTAG device.
	SEC_TMS_TRIS = 0;		// Enable output to TMS pin of secondary JTAG device.
	SEC_TDI_TRIS = 0;		// Enable output to TDI pin of secondary JTAG device.
	SEC_TDO_TRIS = 1;		// Enable input from TDO pin of secondary JTAG device.

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
	flag.disable_sec_return = 0;

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
	byte *tdi, *tdo;				// Pointers to the currently-active endpoint buffers for TDI and TDO bits.
	long num_bits;					// # of total bits in stream of bits sent to and from the JTAG device.
	byte num_final_bits;			// # of bits in the final packet of TDI/TDO bits.
	long num_bytes;					// # of total bytes in the stream of TDI/TDO bits.
	byte num_final_bytes;			// # of bytes in the final packet of TDI/TDO bits.
	byte bit_mask;					// Mask to select bit from a byte.
	byte bit_cntr;					// Counter within a byte of bits.
	byte tdi_byte, tdo_byte;		// Temporary bytes of TDI and TDO bits.
	static byte sec_present = NO;	// True if the secondary JTAG device is present.
	static byte sec_tck_inv = NO;	// True if there is an inverter on the secondary JTAG TCK.
	static byte sec_tdo_inv = NO;	// True if there is an inverter on the secondary JTAG TDO.
	static byte use_mssp = USE_MSSP;	// True if MSSP is used to drive JTAG pins; false if bit-banging is used.
	
	// Check for the presence of the secondary JTAG port
	if(!sec_present)
	{
		sec_present = SenseSecondaryInverters(&sec_tck_inv, &sec_tdo_inv);
		SEC_TCK = sec_tck_inv;	// SEC_TCK = 0 if no inverter, 1 if inverter is present.
		sec_tdo_inv_mask = sec_tdo_inv ? 0xFF : 0x00;
		// The XSA-50, XSA-100 and XSB-300E have dual inverters in the TCK signal that goes to the FPGA.
		// This corrupts the timing of the TCK w.r.t. the TDI and TMS signals.  So use bit-banging in these cases.
		use_mssp = sec_tck_inv ? NO : USE_MSSP;
	}

	num_return_bytes = 0;	// Initially, assume nothing needs to be returned.
	
	// Process packets received through the primary endpoint.
    if(USBGenPrimaryRead((byte*)&dataPacket,sizeof(dataPacket)))
    {
		USBDriverService();
		
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

            case SENSE_INVERTERS_CMD:
				sec_present = SenseSecondaryInverters(&sec_tck_inv, &sec_tdo_inv);
				SEC_TCK = sec_tck_inv;	// SEC_TCK = 0 if no inverter, 1 if inverter is present.
				sec_tdo_inv_mask = sec_tdo_inv ? 0xFF : 0x00;
				use_mssp = sec_tck_inv ? NO : USE_MSSP; // Don't use MSSP if dual inverters are in the TCK line to the FPGA; bit-bang instead.
				num_return_bytes = 1;	// just return the command as an acknowledgement.
            	break;
				
			case SINGLE_TEST_VECTOR_CMD:
				// Output a single, byte-wide test vector.
				OutputTestVector(dataPacket.test_vector, dataPacket.mask);
				dataPacket.test_vector = 0x00;	// Over-write test vector with the response to the test vector.
				num_return_bytes = 3;			// Return the packet with the response.
				break;
				
			case GET_TEST_VECTOR_CMD:
				// Get the test vector currently being output.				
				dataPacket.test_vector = curr_test_vector;
				num_return_bytes = 3;
				break;
				
			case SET_OSC_FREQ_CMD:
				// Set the frequency of the DS1075 programmable osc on the XSA-50/100 Boards.
				dataPacket.status = SetOscFrequency(dataPacket.div, dataPacket.extOscPresent);
				num_return_bytes = 5;	// return the command with the status
				break;

			case TMS_TDI_CMD:
				// Output TMS and TDI values and pulse TCK.
				TMS = dataPacket.tms;
				TDI = dataPacket.tdi;
				TCK = 1;
				TCK = 0;
				num_return_bytes = 0;			// Don't return any packets.
                break;

			case TMS_TDI_TDO_CMD:
				// Sample TDO, output TMS and TDI values, pulse TCK, and return TDO value.
				dataPacket.tdo = TDO;	// Place TDO pin value into the command packet.
				TMS = dataPacket.tms;
				TDI = dataPacket.tdi;
				TCK = 1;
				TCK = 0;
				num_return_bytes = 2;			// Return the packet with the TDO value in it.
                break;

			case TDI_CMD:		// get USB packets of TDI data, output data to TDI pin of JTAG device
			case TDI_TDO_CMD:	// get USB packets, output data to TDI pin, input data from TDO pin, send USB packets  
			case TDO_CMD:		// input data from TDO pin of JTAG device, send USB packets of TDO data
				blink_counter = MAX_BYTE_VAL;	// Blink LED continuously during the long duration of this command.

				// The first packet received contains the TDI_CMD command and the number
				// of TDI bits that will follow in succeeding packets.
				num_bits = dataPacket.num_bits;

				// Exit if no TDI bits will follow (this is probably an error...).
				if(num_bits == 0)
					break;

				num_bytes = (num_bits+7)/8;  // Total number of bytes in all the packets that will follow.

				TCK = 0; // Initialize TCK (should have been low already).
				TMS = 0; // Initialize TMS to keep TAP FSM in Shift-IR or Shift-DR state).

				if(use_mssp && num_bits>8)
				{
					TCK_TRIS = 1;	// Disable the TCK output so that the clock won't glitch when the MSSP is enabled.
					SSPCON1bits.SSPEN = 1;	// Enable the MSSP.
					TCK_TRIS = 0;	// Enable the TCK output after the MSSP glitch is over.
				}

				// Process the first M-1 of M packets that are completely filled with TDI and/or TDO bits.
				data_index = 0;
				tdi_data[0] = usbgen_primary_out0;
				tdi_data[1] = usbgen_primary_out1;
				tdo_data[0] = usbgen_primary_in0;
				tdo_data[1] = usbgen_primary_in1;
				for( ; num_bytes > USBGEN_EP_SIZE; num_bytes-=USBGEN_EP_SIZE)
				{
					if(blink_counter == 0U)
						blink_counter = MAX_BYTE_VAL;	// Blink LED continuously during the long duration of this command.

					if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
					{
						// Wait until a completely filled packet of TDI bits arrives.
						while(mUSBGenPrimaryRxIsBusy()) ;

						// Initialize a pointer to the buffer of just-received TDI bits and
						// change the buffer address in the endpoint so it will place the next
						// packet of TDI bits in another area of memory while the current packet
						// is sent to the JTAG port. 
						tdi = tdi_data[data_index];	// Init pointer to the just-received TDI data.
						data_index ^= 1;			// point to next ping-pong buffer
						tdo = tdo_data[data_index]; // TDO data will be written here.
						USBGEN_BD_PRIMARY_OUT.ADR = tdi_data[data_index];	// Change buffer address in endpoint.
			        	USBGEN_BD_PRIMARY_OUT.Cnt = USBGEN_EP_SIZE;
						USBDriverService();							// Clear USB interrupt from stack.
	       				mUSBBufferReady(USBGEN_BD_PRIMARY_OUT);		// Enable the endpoint to receive more TDI data.
       				}
       				else // dataPacket.cmd == TDO_CMD
       				{
						data_index ^= 1;			// point to next ping-pong buffer
						tdo = tdo_data[data_index]; // TDO data will be written here.
					}

					// Process the bytes in the TDI packet.
					buffer_cntr = USBGEN_EP_SIZE;
					save_FSR0 = FSR0;
					save_FSR1 = FSR1;

					if(dataPacket.cmd == TDI_CMD)
					{
						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
						FSR0 = (word)tdi;
						if(use_mssp)
						{
							_asm
							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
							MOVFF	TABLAT,SSPBUF			// Load TDI byte into SPI transmitter.
							NOP
							NOP
						PRI_TDI_LOOP_0:
							DCFSNZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue if not zero
							BRA		PRI_TDI_LOOP_1
							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte just to clear the buffer-full flag (don't use TDO).
							MOVFF	TABLAT,SSPBUF			// Load TDI byte into SPI transmitter ASAP.
							BRA		PRI_TDI_LOOP_0
						PRI_TDI_LOOP_1:
							NOP
							NOP
							NOP
							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte just to clear the buffer-full flag (don't use TDO).
							_endasm
						}
						else
						{
						_asm
						PRI_TDI_LOOP_0:
							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
							// Bit 7 of a byte of TDI/TDO bits.
							RLCF	TABLAT,1,ACCESS			// Rotate TDI bit into carry.
							BSF		TDI_ASM				// Set TDI pin of JTAG device to value of TDI bit.
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM				// Toggle TCK pin of JTAG device.
							BCF		TCK_ASM
							// Bit 6
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 5
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 4
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 3
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 2
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 1
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 0
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
							BRA		PRI_TDI_LOOP_0			//   processing TDI bytes until it is 0.
							_endasm
						}
					}
					else if(dataPacket.cmd == TDI_TDO_CMD)
					{
						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
						FSR0 = (word)tdi;
						FSR1 = (word)tdo;
						if(use_mssp)
						{
							_asm
						PRI_TDI_TDO_LOOP_0:
							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
							MOVFF	TABLAT,SSPBUF			// Load TDI byte into SPI transmitter.
							NOP								// The NOPs are used to insert delay while the SSPBUF is tx/rx'ed.
							NOP
							NOP
							NOP
							NOP
							NOP
							NOP
							NOP
							NOP
							NOP
							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
							MOVFF	TABLAT,POSTINC1			// Store the TDO byte into the buffer and inc. the pointer.
							DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
							BRA		PRI_TDI_TDO_LOOP_0		//   processing TDI bytes until it is 0.
							_endasm
						}
						else
						{
							_asm
						PRI_TDI_TDO_LOOP_0:
							MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
							// Bit 7 of a byte of TDI/TDO bits.
							BCF		CARRY_BIT_ASM			// Set carry to value on TDO pin of JTAG device.
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS			// Rotate TDO value into TABLAT register and TDI bit into carry.
							BSF		TDI_ASM				// Set TDI pin of JTAG device to value of TDI bit.
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM				// Toggle TCK pin of JTAG device.
							BCF		TCK_ASM
							// Bit 6
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 5
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 4
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 3
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 2
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 1
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 0
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TDI_ASM
							BTFSS	CARRY_BIT_ASM
							BCF		TDI_ASM
							BSF		TCK_ASM
							BCF		TCK_ASM
	
							MOVFF	TABLAT,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
							MOVFF	TABLAT,POSTINC1			// Store the TDO byte into the buffer and inc. the pointer.
							DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
							BRA		PRI_TDI_TDO_LOOP_0		//   processing TDI bytes until it is 0.
							_endasm
						}
					}
					else // dataPacket.cmd == TDO_CMD
					{
						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
						FSR0 = (word)tdo;
						if(use_mssp)
						{
							_asm
							MOVLW	0						// Load the SPI transmitter with 0's
							MOVWF	SSPBUF,ACCESS			//   so TDI is cleared while TDO is collected.
							NOP								// The NOPs are used to insert delay while the SSPBUF is tx/rx'ed.
							NOP
							NOP
							NOP
							NOP
							NOP
						PRI_TDO_LOOP_0:
							NOP
							NOP
							DCFSNZ	buffer_cntr,1,ACCESS
							BRA		PRI_TDO_LOOP_1
							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
							MOVWF	SSPBUF,ACCESS
							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
							MOVFF	TABLAT,POSTINC0			// Store the TDO byte into the buffer and inc. the pointer.
							BRA		PRI_TDO_LOOP_0
						PRI_TDO_LOOP_1:
							MOVFF	SSPBUF,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
							MOVFF	TABLAT,POSTINC0			// Store the TDO byte into the buffer and inc. the pointer.
							_endasm
						}
						else
						{
							_asm
						PRI_TDO_LOOP_0:
							// Bit 7 of a byte of TDI/TDO bits.
							BCF		CARRY_BIT_ASM			// Set carry to value on TDO pin of JTAG device.
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS			// Rotate TDO value into TABLAT register.
							BSF		TCK_ASM				// Toggle TCK pin of JTAG device.
							BCF		TCK_ASM
							// Bit 6
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 5
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 4
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 3
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 2
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 1
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
							// Bit 0
							BCF		CARRY_BIT_ASM
							BTFSC	TDO_ASM
							BSF		CARRY_BIT_ASM
							RLCF	TABLAT,1,ACCESS
							BSF		TCK_ASM
							BCF		TCK_ASM
	
							MOVFF	TABLAT,TBLPTRL			// Get the TDO byte that was received and use it to index into the bit-order table.
							TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
							MOVFF	TABLAT,POSTINC0			// Store the TDO byte into the buffer and inc. the pointer.
							DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
							BRA		PRI_TDO_LOOP_0			//   processing TDI bytes until it is 0.
							_endasm
						}
					}  // All the TDI bytes in the current packet have been processed.

					FSR1 = save_FSR1;
					FSR0 = save_FSR0;

					// Once all the TDI bits from a complete packet are sent to the JTAG port,
					// send all the recorded TDO bits back in a complete packet.
					if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
					{
	       				while(mUSBGenPrimaryTxIsBusy()) ;
						USBGEN_BD_PRIMARY_IN.ADR = tdo_data[data_index];
					    USBGEN_BD_PRIMARY_IN.Cnt = USBGEN_EP_SIZE;
					    mUSBBufferReady(USBGEN_BD_PRIMARY_IN);
						USBDriverService();
					}
				}  // First M-1 TDI packets have been processed.

				num_final_bytes = num_bytes;

				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
				{
					// Now wait until the final TDI packet arrives.
					while(mUSBGenPrimaryRxIsBusy()) ;
					USBDriverService();	// Clear USB interrupt from stack.
				}

				// Process all except the last byte in the final packet of TDI bits.
				tdi = tdi_data[data_index];
				data_index ^= 1;			// point to next ping-pong buffer
				tdo = tdo_data[data_index];
				for(buffer_cntr=num_final_bytes ; buffer_cntr>1U; buffer_cntr--)
				{
					// Read a byte from the packet, re-order the bits (if necessary), and transmit it
					// through the SSP starting at the most-significant bit.
					if(use_mssp)
					{
						if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
							SSPBUF = reverse_bits[*tdi++];
						else
							SSPBUF = 0;
							_asm
						BF_TEST_LOOP_1:
							MOVF	SSPSTAT,TO_WREG,ACCESS	// Wait for the TDI byte to be transmitted.
							BTFSS	MSSP_BF_ASM				// (Can't check SSPSTAT directly or else the transfer doesn't work.)
							BRA		BF_TEST_LOOP_1
							_endasm
						*tdo++ = reverse_bits[SSPBUF];	// Always read the SSPBUFF to clear the buffer-full flag, even if TDO bits are not needed.
					}
					else
					{
						if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
							tdi_byte = reverse_bits[*tdi++];
						else
							tdi_byte = 0;
						tdo_byte = 0;
						for(bit_cntr=8, bit_mask=0x80; bit_cntr>0; bit_cntr--, bit_mask>>=1)
						{
							if(TDO)
								tdo_byte |= bit_mask;
							TDI = tdi_byte & bit_mask ? 1:0;
							TCK = 1;
							TCK = 0;
						} // The final bits in the last TDI byte have been processed.
						if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
							*tdo++ = reverse_bits[tdo_byte];
					}
				}

				// Send the last few bits of the last packet of TDI bits.
				if(use_mssp)
				{
					TCK = 0;
					SSPCON1bits.SSPEN = 0;	// Turn off the MSSP.  The remaining bits are transmitted manually.
				}
				
				// Compute the number of TDI bits in the final byte of the final packet.
				// (This computation only works because num_bits != 0.)
				bit_cntr = num_bits & 0x7;
				if(bit_cntr==0U)
					bit_cntr = 8U;

				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
					tdi_byte = reverse_bits[*tdi];
				else
					tdi_byte = 0;
				tdo_byte = 0;
				for(bit_mask=0x80; bit_cntr>0; bit_cntr--, bit_mask>>=1)
				{
					if(bit_cntr==1U)
						TMS = 1;	// Raise TMS to exit Shift-IR or Shift-DR state on the final TDI bit.
					if(TDO)
						tdo_byte |= bit_mask;
					TDI = tdi_byte & bit_mask ? 1:0;
					TCK = 1;
					TCK = 0;
				} // The final bits in the last TDI byte have been processed.
				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
					*tdo = reverse_bits[tdo_byte];

				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
				{
					// Send back the final packet of TDO bits.
	   				while(mUSBGenPrimaryTxIsBusy()) ;
					USBGEN_BD_PRIMARY_IN.ADR = tdo_data[data_index];
				    USBGEN_BD_PRIMARY_IN.Cnt = num_final_bytes;
				    mUSBBufferReady(USBGEN_BD_PRIMARY_IN);
					USBDriverService();
				}
				
				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
				{
					// We have transmitted the last byte from the endpoint buffer, so reset the endpoint
					// to the default buffer and re-enable the endpoint.
					USBGEN_BD_PRIMARY_OUT.ADR = usbgen_primary_out0;
			        USBGEN_BD_PRIMARY_OUT.Cnt = USBGEN_EP_SIZE;
					mUSBBufferReady(USBGEN_BD_PRIMARY_OUT);
				}

				num_return_bytes = 0;	// Any packets with TDO data have already been sent.
				
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

			case NULL_TDI_CMD:
				// The first packet received contains the TDI_CMD command and the number
				// of TDI bits that will follow in succeeding packets.
				num_bits = dataPacket.num_bits;

				// Exit if no TDI bits will follow (this is probably an error...).
				if(num_bits == 0)
					break;

				num_bytes = (num_bits+8*sizeof(usbgen_primary_out0)-1)/(8*sizeof(usbgen_primary_out0));
				for( ; num_bytes>0; num_bytes--)
				{
					while(mUSBGenPrimaryRxIsBusy()) ;
			        USBGEN_BD_PRIMARY_OUT.Cnt = sizeof(usbgen_primary_out0);
					USBDriverService();						// Clear USB interrupt from stack.
        			mUSBBufferReady(USBGEN_BD_PRIMARY_OUT);			// Enable the endpoint to receive more TDI data.
				}					
				num_return_bytes = 0;			// don't return any packets
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
            if(!mUSBGenPrimaryTxIsBusy()) // Send the packet once the transmitter is not busy.
                USBGenPrimaryWrite((byte*)&dataPacket,num_return_bytes);
        }//end if
    }//end if

	// Process packets received through the secondary endpoint.
    if(USBGenSecondaryRead((byte*)&dataPacket,sizeof(dataPacket)))
    {
		USBDriverService();

		blink_counter = NUM_ACTIVITY_BLINKS;	// Blink the LED whenever a USB transaction occurs.

        switch(dataPacket.cmd)	// Process the contents of the packet based on the command byte.
        {
            case ID_BOARD:
            	// Blink the LED in order to identify the board.
                blink_counter = 50;
                num_return_bytes = 1;
                break;
                
            case ENABLE_RETURN_CMD:
            	flag.disable_sec_return = 0;
            	break;
                
            case DISABLE_RETURN_CMD:
            	flag.disable_sec_return = 1;
            	break;

            case INFO_CMD:
				// Return a packet with information about this USB interface device.
				strcpypgm2ram(dataPacket.info_str, info_str);
                num_return_bytes=sizeof(dataPacket);	// Return information stored in packet.
                break;

            case SENSE_INVERTERS_CMD:
				sec_present = SenseSecondaryInverters(&sec_tck_inv, &sec_tdo_inv);
				SEC_TCK = sec_tck_inv;	// SEC_TCK = 0 if no inverter, 1 if inverter is present.
				sec_tdo_inv_mask = sec_tdo_inv ? 0xFF : 0x00;
				use_mssp = sec_tck_inv ? NO : USE_MSSP; // Don't use MSSP if dual inverters are in the TCK line to the FPGA; bit-bang instead.
				num_return_bytes = 1;	// just return the command as an acknowledgement.
            	break;
				
			case SET_OSC_FREQ_CMD:
				// Set the frequency of the DS1075 programmable osc on the XSA-50/100 Boards.
				dataPacket.status = SetOscFrequency(dataPacket.div, dataPacket.extOscPresent);
				num_return_bytes = 5;	// return the command with the status
				break;

			case TMS_TDI_CMD:
				// Output TMS and TDI values and pulse TCK.
				SEC_TMS = dataPacket.tms;
				SEC_TDI = dataPacket.tdi;
				SEC_TCK = ~sec_tck_inv;
				SEC_TCK = sec_tck_inv;
				num_return_bytes = 0;			// Don't return any packets.
                break;

			case TMS_TDI_TDO_CMD:
				// Sample TDO, output TMS and TDI values, pulse TCK, and return TDO value.
				dataPacket.tdo = SEC_TDO ^ sec_tdo_inv;	// Place TDO pin value into the command packet.
				SEC_TMS = dataPacket.tms;
				SEC_TDI = dataPacket.tdi;
				SEC_TCK = ~sec_tck_inv;
				SEC_TCK = sec_tck_inv;
				num_return_bytes = 2;			// Return the packet with the TDO value in it.
                break;

			case TDI_CMD:
			case TDI_TDO_CMD:
			case TDO_CMD:
				blink_counter = MAX_BYTE_VAL;	// Blink LED continuously during the long duration of this command.

				// The first packet received contains the TDI_CMD command and the number
				// of TDI bits that will follow in succeeding packets.
				num_bits = dataPacket.num_bits;

				// Exit if no TDI bits will follow (this is probably an error...).
				if(num_bits == 0)
					break;

				num_bytes = (num_bits+7)/8;  // Number of bytes in succeeding packets of TDI bits.

				SEC_TCK = sec_tck_inv; // Initialize TCK to low level (depending upon TCK inverter).
				SEC_TMS = 0; // Initialize TMS to keep TAP FSM in Shift-IR or Shift-DR state).

				// Process the first M-1 of M packets that are completely filled with TDI bits.
				data_index = 0;
				tdi_data[0] = usbgen_secondary_out0;
				tdi_data[1] = usbgen_secondary_out1;
				tdo_data[0] = usbgen_secondary_in0;
				tdo_data[1] = usbgen_secondary_in1;
				for( ; num_bytes > USBGEN_EP_SIZE; num_bytes-=USBGEN_EP_SIZE)
				{
					if(blink_counter == 0U)
						blink_counter = MAX_BYTE_VAL;	// Blink LED continuously during the long duration of this command.

					if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
					{
						// Wait until a completely filled packet of TDI bits arrives.
						while(mUSBGenSecondaryRxIsBusy()) ;
	
						// Initialize a pointer to the buffer of just-received TDI bits and
						// change the buffer address in the endpoint so it will place the next
						// packet of TDI bits in another area of memory while the current packet
						// is sent to the JTAG port. 
						tdi = tdi_data[data_index];		// Init pointer to the just-received TDI data.
						data_index ^= 1;				// Point to next ping-pong buffer.
						tdo = tdo_data[data_index]; 	// TDO data will be written here.
						USBGEN_BD_SECONDARY_OUT.ADR = tdi_data[data_index];	// Change buffer address in endpoint.
			        	USBGEN_BD_SECONDARY_OUT.Cnt = USBGEN_EP_SIZE;
						USBDriverService();							// Clear USB interrupt from stack.
	       				mUSBBufferReady(USBGEN_BD_SECONDARY_OUT);	// Enable the endpoint to receive more TDI data.
       				}
       				else // dataPacket.cmd == TDO_CMD
       				{
						data_index ^= 1;				// point to next ping-pong buffer
						tdo = tdo_data[data_index]; 	// TDO data will be written here.
	       			}

					// Process the bytes in the TDI packet.
					buffer_cntr = USBGEN_EP_SIZE;
					save_FSR0 = FSR0;
					save_FSR1 = FSR1;

					if(dataPacket.cmd == TDI_CMD)
					{
						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
						FSR0 = (word)tdi;
						
						_asm
					SEC_TDI_LOOP_0:
						MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
						TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
						// Bit 7 of a byte of TDI/TDO bits.
						RLCF	TABLAT,1,ACCESS			// Rotate TDI bit into carry.
						BSF		SEC_TDI_ASM				// Set TDI pin of JTAG device to value of TDI bit.
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 6
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 5
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 4
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 3
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 2
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 1
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 0
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
						BRA		SEC_TDI_LOOP_0			//   processing TDI bytes until it is 0.
						_endasm
					}  
					else if(dataPacket.cmd == TDI_TDO_CMD)
					{
						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
						FSR0 = (word)tdi;
						FSR1 = (word)tdo;
						
						_asm
					SEC_TDI_TDO_LOOP_0:
						MOVFF	POSTINC0,TBLPTRL		// Get the current TDI byte and use it to index into the bit-order table.
						TBLRD							// TABLAT now contains the TDI byte in the proper bit-order.
						// Bit 7 of a byte of TDI/TDO bits.
						BCF		CARRY_BIT_ASM			// Set carry to value on TDO pin of JTAG device.
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS			// Rotate TDO value into TABLAT register and TDI bit into carry.
						BSF		SEC_TDI_ASM				// Set TDI pin of JTAG device to value of TDI bit.
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 6
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 5
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 4
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 3
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 2
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 1
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 0
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BSF		SEC_TDI_ASM
						BTFSS	CARRY_BIT_ASM
						BCF		SEC_TDI_ASM
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM

						MOVF	sec_tdo_inv_mask,0,ACCESS	// Load TDO inversion mask into W.
						XORWF	TABLAT,1,ACCESS			// Do/Don't invert the TDO bits in TABLAT.
						MOVFF	TABLAT,TBLPTRL			// Use the TDO byte to index into the bit-order table.
						TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
						MOVFF	TABLAT,POSTINC1			// Store the TDO byte into the buffer and inc. the pointer.
						DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
						BRA		SEC_TDI_TDO_LOOP_0		//   processing TDI bytes until it is 0.
						_endasm
					}
					else // dataPacket.cmd = TDO_CMD
					{
						TBLPTR = (short long)reverse_bits;	// Setup the pointer to the bit-order table.
						FSR0 = (word)tdo;
						
						_asm
					SEC_TDO_LOOP_0:
						// Bit 7 of a byte of TDI/TDO bits.
						BCF		CARRY_BIT_ASM			// Set carry to value on TDO pin of JTAG device.
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS			// Rotate TDO value into TABLAT register.
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 6
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 5
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 4
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 3
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 2
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 1
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM
						// Bit 0
						BCF		CARRY_BIT_ASM
						BTFSC	SEC_TDO_ASM
						BSF		CARRY_BIT_ASM
						RLCF	TABLAT,1,ACCESS
						BTG		SEC_TCK_ASM				// Toggle TCK pin of JTAG device.
						BTG		SEC_TCK_ASM

						MOVF	sec_tdo_inv_mask,0,ACCESS	// Load TDO inversion mask into W.
						XORWF	TABLAT,1,ACCESS			// Do/Don't invert the TDO bits in TABLAT.
						MOVFF	TABLAT,TBLPTRL			// Use the TDO byte to index into the bit-order table.
						TBLRD							// TABLAT now contains the TDO byte in the proper bit-order.
						MOVFF	TABLAT,POSTINC0			// Store the TDO byte into the buffer and inc. the pointer.
						DECFSZ	buffer_cntr,1,ACCESS	// Decrement the buffer counter and continue
						BRA		SEC_TDO_LOOP_0			//   processing TDI bytes until it is 0.
						_endasm
					}	// All the TDI bytes in the current packet have been processed.

					FSR1 = save_FSR1;
					FSR0 = save_FSR0;

					if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
					{
						// Once all the TDI bits from a complete packet are sent to the JTAG port,
						// send all the recorded TDO bits back in a complete packet.
	       				while(mUSBGenSecondaryTxIsBusy()) ;
						USBGEN_BD_SECONDARY_IN.ADR = tdo_data[data_index];
					    USBGEN_BD_SECONDARY_IN.Cnt = USBGEN_EP_SIZE;
					    mUSBBufferReady(USBGEN_BD_SECONDARY_IN);
						USBDriverService();
					}
				}  // First M-1 TDI packets have been processed.

				num_final_bytes = num_bytes;

				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
				{
					// Now wait until the final TDI packet arrives.
					while(mUSBGenSecondaryRxIsBusy()) ;
					USBDriverService();	// Clear USB interrupt from stack.
				}

				// Process all except the last byte in the final packet of TDI bits.
				tdi = tdi_data[data_index];
				data_index ^= 1;				// point to next ping-pong buffer
				tdo = tdo_data[data_index];
				for(buffer_cntr=num_final_bytes ; buffer_cntr>1U; buffer_cntr--)
				{
					// Read a byte from the packet, re-order the bits (if necessary), and transmit it
					// starting at the most-significant bit.
					if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
						tdi_byte = reverse_bits[*tdi++];
					else
						tdi_byte = 0;
					tdo_byte = 0;
					for(bit_cntr=8U, bit_mask=0x80U; bit_cntr>0U; bit_cntr--, bit_mask>>=1)
					{
						if(SEC_TDO)
							tdo_byte |= bit_mask;
						SEC_TDI = tdi_byte & bit_mask ? 1:0;
						SEC_TCK = ~SEC_TCK;
						SEC_TCK = ~SEC_TCK;
					} // The final bits in the last TDI byte have been processed.
					if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
						*tdo++ = reverse_bits[tdo_byte ^ sec_tdo_inv_mask];
				}

				// Compute the number of TDI bits in the final byte of the final packet.
				// (This computation only works because num_bits != 0.)
				bit_cntr = num_bits & 0x7;
				if(bit_cntr==0U)
					bit_cntr = 8U;

				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
					tdi_byte = reverse_bits[*tdi];
				else
					tdi_byte = 0;
				tdo_byte = 0;
				for(bit_mask=0x80U; bit_cntr>0U; bit_cntr--, bit_mask>>=1)
				{
					if(bit_cntr==1U)
						SEC_TMS = 1;	// Raise TMS to exit Shift-IR or Shift-DR state on the final TDI bit.
					if(SEC_TDO)
						tdo_byte |= bit_mask;
					SEC_TDI = tdi_byte & bit_mask ? 1:0;
					SEC_TCK = ~SEC_TCK;
					SEC_TCK = ~SEC_TCK;
				} // The final bits in the last TDI byte have been processed.
				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
					*tdo = reverse_bits[tdo_byte ^ sec_tdo_inv_mask];

				// Send back the final packet of TDO bits.
				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDO_CMD)
				{
       				while(mUSBGenSecondaryTxIsBusy()) ;
					USBGEN_BD_SECONDARY_IN.ADR = tdo_data[data_index];
				    USBGEN_BD_SECONDARY_IN.Cnt = num_final_bytes;
				    mUSBBufferReady(USBGEN_BD_SECONDARY_IN);
					USBDriverService();
				}

				if(dataPacket.cmd == TDI_TDO_CMD || dataPacket.cmd == TDI_CMD)
				{
					// We have transmitted the last byte from the endpoint buffer, so reset the endpoint
					// to the default buffer and re-enable the endpoint.
					USBGEN_BD_SECONDARY_OUT.ADR = usbgen_secondary_out0;
			        USBGEN_BD_SECONDARY_OUT.Cnt = USBGEN_EP_SIZE;
					mUSBBufferReady(USBGEN_BD_SECONDARY_OUT);
				}
				
				num_return_bytes = 0; // Any packets with TDO data have already been sent.

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
						SEC_TCK = ~sec_tck_inv;
						SEC_TCK = sec_tck_inv;
					}
				}
				num_return_bytes = 5; // return the entire command as an acknowledgement
                break;

			case NULL_TDI_CMD:
				// The first packet received contains the TDI_CMD command and the number
				// of TDI bits that will follow in succeeding packets.
				num_bits = dataPacket.num_bits;

				// Exit if no TDI bits will follow (this is probably an error...).
				if(num_bits == 0)
					break;

				num_bytes = (num_bits+8*sizeof(usbgen_secondary_out0)-1)/(8*sizeof(usbgen_secondary_out0));
				for( ; num_bytes>0; num_bytes--)
				{
					while(mUSBGenSecondaryRxIsBusy()) ;
			        USBGEN_BD_SECONDARY_OUT.Cnt = sizeof(usbgen_secondary_out0);
					USBDriverService();						// Clear USB interrupt from stack.
        			mUSBBufferReady(USBGEN_BD_SECONDARY_OUT);			// Enable the endpoint to receive more TDI data.
				}					
				num_return_bytes = 0;			// don't return any packets
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
        if(!flag.disable_sec_return && num_return_bytes != 0U)
        {
            if(!mUSBGenSecondaryTxIsBusy()) // Send the packet once the transmitter is not busy.
                USBGenSecondaryWrite((byte*)&dataPacket,num_return_bytes);
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


/******************************************************************************
 * Function:        void OutputTestVector(tv,mask)
 *
 * PreCondition:    None
 *
 * Input:           tv - test vector
 *					mask - mask for test vector (0's for mask; 1's for bits to output).
 *
 * Output:          None
 *
 * Side Effects:    None
 *
 * Overview:        Outputs the unmasked bits to the FPGA.
 *
 * Note:            
 *****************************************************************************/
static void OutputTestVector(byte tv, byte mask)
{
	curr_test_vector = (tv & mask) | (curr_test_vector & ~mask);
	ENABLE_TEST_VECTOR = 0;	// Disable test vector clock.
	PPD0 = 1;				// Raise clock while disabled to get ready to load test vector.
	ENABLE_TEST_VECTOR = 1;	// Now enable the test vector clock.
	tv = (curr_test_vector & 0xF0) | (PORTD & 0x0F);
	PORTD = tv;
	PPD0 = 0;				// Clock-in upper half of test vector.
	tv = ((curr_test_vector<<4) & 0xF0) | (PORTD & 0x0F);
	PORTD = tv;
	PPD0 = 1;				// Clock-in lower half of test vector.
}


/******************************************************************************
 * Function:        char SenseSecondaryInverters(byte *tck_inv, byte *tdo_inv)
 *
 * PreCondition:    None
 *
 * Input:           tck_inv - pointer to TCK inversion mask.
 *					tdo_inv - pointer to TDO inversion mask.
 *
 * Output:          tck_inv - loaded with 1 if TCK pin is inverted, 0 otherwise.
 *					tdo_inv - loaded with 1 if TDO pin is inverted, 0 otherwise.
 *					Returns zero if no device is connected, non-zero otherwise.
 *
 * Side Effects:    None
 *
 * Overview:        Detects the presence of inverters on the secondary JTAG port
 *					TCK and TDO pins.  Also detects the presence of the device.
 *
 * Note:            
 *****************************************************************************/

static void PulseSEC_TCK(void)
{
	// This is a little helper function to toggle the secondary
	// JTAG clock pin.
	SEC_TCK = ~SEC_TCK;
	SEC_TCK = ~SEC_TCK;
}

static char SenseSecondaryInverters(byte *tck_inv, byte *tdo_inv)
{
	byte i;
	byte prev_tdo;
	
	// Initialize TAP clock to a known level.
	SEC_TCK = 0;

	// Reset the JTAG TAP FSM.
	SEC_TMS = 1;
	for(i=0; i<5U; i++)
	{
		PulseSEC_TCK();
	}
	
	// Enter BYPASS instruction.
	SEC_TMS = 0; PulseSEC_TCK();	// Run-Test/Idle state
	SEC_TMS = 1; PulseSEC_TCK();	// Select-DR-Scan state
	SEC_TMS = 1; PulseSEC_TCK();	// Select-IR-Scan state
	SEC_TMS = 0; PulseSEC_TCK();	// Capture-IR state
	SEC_TMS = 0; PulseSEC_TCK();	// Shift-IR state
	SEC_TDI = 1;					// Enter all 1's into IR for BYPASS instruction.
	for(i=0; i<10U; i++)
		PulseSEC_TCK();
	SEC_TMS = 1; PulseSEC_TCK();	// Exit1-IR state
	SEC_TMS = 1; PulseSEC_TCK();	// Update-IR state
	SEC_TMS = 1; PulseSEC_TCK();	// Select-DR-Scan state
	SEC_TMS = 0; PulseSEC_TCK();	// Capture-DR state
	SEC_TMS = 0; PulseSEC_TCK();	// Shift-DR state

	// The BYPASS instruction is now in effect and the TAP FSM is in the
	// Shift-DR state, so the value on TDI should appear after a
	// pulse on TCK.
	
	// Check for an inverter on the TDO pin.
	PulseSEC_TCK();		// Clock TDI through to TDO.
	PulseSEC_TCK();		// Need two clock pulses since TCK may be inverted.
	*tdo_inv = 0;		// Assume there is no inverter on TDO.
	if(SEC_TDO != SEC_TDI)	// An inverter is present if TDO != TDI.
		*tdo_inv = 1;	// Indicate there is an inverter on TDO.

	// Send some bits from TDI to TDO to see if there is anything connected.
	for(i=0; i<2U; i++)
	{
		byte expected_tdo;
		SEC_TDI = ~SEC_TDI;		// Toggle TDI pin so TDO will change.
		// Determine expected value of TDO based on TDI and presence/absence of TDO inverter.
		expected_tdo = SEC_TDI;
		if(*tdo_inv)
			expected_tdo = ~SEC_TDI;	// Will be either 0xFE or 0xFF.
		expected_tdo &= 0x01;	// Should only be 1 or 0, not 0xFE or 0xFF.
		// Clock TDI through to TDO.
		PulseSEC_TCK();
		PulseSEC_TCK();
		// Check TDO to see if it has changed to its expected value.
		if(SEC_TDO != expected_tdo)
			return 0;	// TDO is not responding, so there is nothing connected.
	}
		
	// Check for an inverter on the TCK pin.
	prev_tdo = SEC_TDO;	// Store the current value on the TDO pin.
	SEC_TDI = ~SEC_TDI;	// Flip TDI so TDO will eventually change.
	do
	{
		SEC_TCK = ~SEC_TCK;			// Toggle TCK...
		Delay1TCY();	// Let TDO settle.
		Delay1TCY();
		Delay1TCY();
	} while(SEC_TDO == prev_tdo);	// ...until the TDO pin changes.
	// An inverter exists on the TCK pin if TDO changes on
	// a rising edge of TCK.
	*tck_inv = 0;
	if(SEC_TCK == 1U)
		*tck_inv = 1;
	
	return 1;
}

/******************************************************************************
 * Function:        bool SetOscFrequency(int div, bool extOscPresent)
 *
 * PreCondition:    None
 *
 * Input:           div - divisor for master frequency.
 *					extOscPresent - if true, master frequency comes from internal 
 *                        source instead of DS1075 internal 100 MHz osc.
 *
 * Output:          Returns true if clock divisor successfully set, false otherwise.
 *
 * Side Effects:    None
 *
 * Overview:        Sets the clock divisor of the DS1075 programmable oscillator
 *                  on the XSA-50, XSA-100 Boards.
 *
 * Note:            
 *****************************************************************************/

#define RESET_DURATION		1200
#define	ONE_DURATION		5L
#define	ZERO_DURATION		112L
#define BIT_DURATION		150L
#define	CMD_SPACING			240
#define OSC_CMD_LENGTH		8
#define OSC_DATA_LENGTH		9
#define OSC_CMD_WR_DIV		1
#define OSC_CMD_WR_MUX		2

// Reset the programmable oscillator.
static void ResetOsc(void)
{
	PPC0 = 0;				// lower data bit 0
	InsertDelay(RESET_DURATION,MICROSECONDS);	// wait for DS1075 to see reset level
	PPC0 = 1;				// now remove reset level
	InsertDelay(RESET_DURATION,MICROSECONDS);	// wait for presence pulse from DS1075
}

// Send a bit of data to the programmable oscillator.
#define SEND_ONE		\
	{ \
		PPC0 = 0; \
		Delay10TCYx((ONE_DURATION * MIPS)/10); \
		PPC0 = 1; \
		Delay10TCYx(((BIT_DURATION-ONE_DURATION)*MIPS)/10); \
	}
#define SEND_ZERO		\
	{ \
		PPC0 = 0; \
		Delay10TCYx((ZERO_DURATION * MIPS)/10); \
		PPC0 = 1; \
		Delay10TCYx(((BIT_DURATION-ZERO_DURATION)*MIPS)/10); \
	}
static void SendOscBit(unsigned int b)
{
	if(b)
		SEND_ONE
	else
		SEND_ZERO
}

// Send a command word to the programmable oscillator.
static void IssueOscCmd(unsigned int cmd)
{
	byte i;
	for(i=0; i<OSC_CMD_LENGTH; i++, cmd>>=1)
		SendOscBit(cmd&1);
}


// Send a data word to the programmable oscillator.
static void SendOscData(unsigned int data)
{
	byte i;
	for(i=0; i<OSC_DATA_LENGTH; i++, data>>=1)
		SendOscBit(data&1);
}


// Set the programmable oscillator frequency.
static BOOL SetOscFrequency(int div, BOOL extOscPresent)
{
	int div1, prescaleOff, prescaleByTwo, powerUp, disable0, mux;
	
	if(div<1)
		return FALSE;
	if(div>2052)
		return FALSE;

	div1 = div==1 ? 1:0;	// set divide-by-1 bit if clock is not divided down
	prescaleOff = 1;		// turn off prescalar
	prescaleByTwo = 0;
	if(!extOscPresent)		// setup prescalar circuitry if DS1075 internal oscillator is used
	{
		if(div>1026)
		{
			prescaleOff = 0;	// turn on the prescalar
			prescaleByTwo = 0;	// enable divide-by-four by turning off the divide-by-two prescalar
			div /= 4;			// reduce divisor
		}
		else if(div>513)
		{
			prescaleOff = 0;	// turn on the prescalar
			prescaleByTwo = 1;	// turn on the divide-by-two prescalar
			div /= 2;
		}
	}
	div = div>513 ? 513:div;	// divisor saturates at 513 if external oscillator is used
	// The divisor must be adjusted to get the frequency right as follows:
	//		original	adjusted	resulting
	//		div			div			frequency
	//		----------------------------------
	//		1			 -1			100 MHz (no division)
	//		2			  0			 50 MHz (divide by 2)
	//		3			  1			 33 MHz (divide by 3)
	//		4			  2			 25 MHz (divide by 4)
	//		...			...			...
	//		511			509			
	//		512			510			
	//		513			511
	div -= 2;

	powerUp = 1;		// keep the oscillator powered up
	disable0 = 1;		// disable the OUT0 output of the DS1075 (it's not connected on the XSA-50/100 Boards)
	mux = (disable0<<5) | (powerUp<<4) | (prescaleByTwo<<3) |(prescaleOff<<2) | (div1<<1) | (extOscPresent ? 1:0);

	PPC0 = 1;	// make sure the osc. config. pin starts out high

	// program divisor register of the DS1075
	ResetOsc();
	IssueOscCmd(OSC_CMD_WR_DIV);
	SendOscData(div);
	InsertDelay(CMD_SPACING,MICROSECONDS);

	// program multiplexor register of the DS1075
	ResetOsc();
	IssueOscCmd(OSC_CMD_WR_MUX);
	SendOscData(mux);
	InsertDelay(CMD_SPACING,MICROSECONDS);

	return TRUE;
}

/** EOF user.c ***************************************************************/
