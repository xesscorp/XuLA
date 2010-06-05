//*********************************************************************
// Module Name: user.h
//
// Copyright 2007 X Engineering Software Systems Corp.
// All rights reserved.
//
// Module Description:
// Header file for the external interface to the user.c module.
//
// Revision: $Id$
//********************************************************************

#ifndef XSUSB_JTAG_H
#define XSUSB_JTAG_H

/** I N C L U D E S **********************************************************/

/** D E F I N I T I O N S ****************************************************/

/** S T R U C T U R E S ******************************************************/

/** P U B L I C  P R O T O T Y P E S *****************************************/

void UserInit(void);	// Initialize the USB-to-JTAG packet processor.
void ProcessIO(void);	// Process USB-to-JTAG packets.

#endif //XSUSB_JTAG_H
