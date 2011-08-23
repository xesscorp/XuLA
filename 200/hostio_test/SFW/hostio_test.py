# /***********************************************************************************
# *   This program is free software; you can redistribute it and/or
# *   modify it under the terms of the GNU General Public License
# *   as published by the Free Software Foundation; either version 2
# *   of the License, or (at your option) any later version.
# *
# *   This program is distributed in the hope that it will be useful,
# *   but WITHOUT ANY WARRANTY; without even the implied warranty of
# *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# *   GNU General Public License for more details.
# *
# *   You should have received a copy of the GNU General Public License
# *   along with this program; if not, write to the Free Software
# *   Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# *   02111-1307, USA.
# *
# *   (c)2011 - X Engineering Software Systems Corp. (www.xess.com)
# ***********************************************************************************/

'''
This program runs tests on a XuLA board whose FPGA has been loaded with
a bitstream for exercising the interface between the FPGA and the host PC.
This program is organized into three parts, one for each of the modules
in the hostio_test circuit:

Part 1: Write and read the single register component using a stream
    of random values. Report any errors that are seen.
    
Part 2: Write and read the block RAM component using a stream of
    random values. Report any errors that are seen.
    
Part 3: Increment and decrement the four-bit counter component and
    display the counter bits after each operation.
'''

from xstoolsapi import *
import sys
import random

USB_ID = 0  # This is the USB index for the XuLA board connected to the host PC.

print '''\n\n\n
##################################################################
# Test the single register in the FPGA hostio_test circuit.
##################################################################
'''
REG_ID = 1  # This is the identifier for the single register in the FPGA.
reg = XsMem(USB_ID, REG_ID)  # Create an object for reading/writing the register.

NUM_TRIALS = 1000  # Number of register reads and writes to do.
REG_MAX_DATA = 2 ** reg.mDataWidth - 1  # Maximum value that can be stored in register.
errorCntr = 0
for i in range(0, NUM_TRIALS):
    wrData = random.randint(0, REG_MAX_DATA + 1)
    reg.Write(0, wrData)
    rdData = reg.Read(0)
    errorCntr += (1 if wrData != rdData else 0)

# Report any comparison errors.
print 'Register was written and read back {0} times and {1} errors occurred.'.format(NUM_TRIALS, errorCntr)

print '''\n\n\n
##################################################################
# Test the block RAM in the FPGA hostio_test circuit.
##################################################################
'''
BRAM_ID = 2  # This is the identifier for the BRAM in the FPGA.
bram = XsMem(USB_ID, BRAM_ID)  # Create an object for reading/writing the BRAM.

# Create constants and lists for reading/writing the BRAM.
BRAM_SIZE = 2 ** bram.mAddrWidth  # Number of words in the BRAM.
BRAM_MAX_DATA = 2 ** bram.mDataWidth - 1  # Maximum value that can be stored in BRAM word.
# Create a list of random integers to write to the BRAM.
wrBram = [random.randint(0, BRAM_MAX_DATA + 1) for i in range(0, BRAM_SIZE)]
# Create a list of integers to receive the values read from the BRAM.
rdBram = [0] * BRAM_SIZE

# Here's the important part: actually writing values to the BRAM and reading them back.
bram.Write(0, wrBram)  # Write the list of values to the BRAM.
bram.Read(0, rdBram)  # Read the list of values from the BRAM.

# Compare the values read back from the BRAM with the values written to it.
errorCntr = sum(map(lambda a, b: (1 if a != b else 0), rdBram, wrBram))

# Report any comparison errors.
print '{0} BRAM locations were written and read back and {1} errors were found.'.format(BRAM_SIZE, errorCntr)

print '''\n\n\n
##################################################################
# Test the four-bit counter in the FPGA hostio_test circuit.
##################################################################
'''
CNTR_ID = 3  # This is the identifier for the counter in the FPGA.
cntr = XsDut(USB_ID, CNTR_ID)
cntBits = [0] * cntr.mNumOutputs
MAX_CNT = 2 ** cntr.mNumOutputs - 1
# These are the settings for the control input of the counter.
INCREMENT = 1
DECREMENT = 0

print 'First, we increment:'
for i in range(0, MAX_CNT + 1):
    cntr.Write(INCREMENT)  # Write the control signal and pulse the counter clock input.
    print '{0:4d} :'.format(cntr.Read()),   # Print the counter's decimal value.
    cntr.Read(cntBits)  # Read the value of the counter again, but now as a list of individual bits.
    PrintBits(cntBits)  # Print the counter bits.

print '\nThen, we decrement:'
for i in range(0, MAX_CNT + 1):
    cntr.Write(DECREMENT)  # Write the control signal and pulse the counter clock input.
    print '{0:4d} :'.format(cntr.Read()),   # Print the counter's decimal value.
    cntr.Read(cntBits)  # Read the value of the counter again, but now as a list of individual bits.
    PrintBits(cntBits)  # Print the counter bits.

print '''\n\n
Waiting in an infinite loop so you can examine the results...
'''
while True:
    pass
