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
This program is organized into four parts, one for each of the modules
in the hostio_test circuit:

Part 1: Write and read the single register component using a stream
    of random values. Report any errors that are seen.
    
Part 2: Write and read the block RAM component using a stream of
    random values. Report any errors that are seen.
    
Part 3: Increment and decrement the four-bit counter component and
    display the counter bits after each operation.
    
Part 4: Send random numbers to a subtractor and check the result against
    the result computed in this program.
'''

from XstoolsApi import *
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
REG_MAX_DATA = 2 ** reg.dataWidth - 1  # Maximum value that can be stored in register.
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
BRAM_SIZE = 2 ** bram.addrWidth  # Number of words in the BRAM.
BRAM_MAX_DATA = 2 ** bram.dataWidth - 1  # Maximum value that can be stored in BRAM word.
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
MAX_CNT = 2 ** cntr.numOutputs - 1
# These are the settings for the control input of the counter.
INCREMENT = 1
DECREMENT = 0

print 'First, we increment:'
for i in range(0, MAX_CNT + 1):
    cnt = cntr.Exec(INCREMENT) # Pulse the counter clock input and read back the counter output.
    print "%4s : %2d" % (cnt.string, cnt.int) # Print the counter bits and their integer equivalent.

print '\nThen, we decrement:'
for i in range(0, MAX_CNT + 1):
    cnt = cntr.Exec(DECREMENT) # Pulse the counter clock input and read back the counter output.
    print "%4s : %2d" % (cnt.string, cnt.int) # Print the counter bits and their integer equivalent.
    
print '''\n\n\n

##################################################################
# Test the eight-bit subtractor in the FPGA hostio_test circuit.
##################################################################
'''
SUBTRACTOR_ID = 4  # This is the identifier for the subtracter in the FPGA.
# Create a DUT object for the adder which takes two 8-bit inputs and outputs an 8-bit result and a carry bit.
adder = XsDut(USB_ID, SUBTRACTOR_ID, [8,8], [8,1])

NUM_TRIALS = 1000
errorCntr = 0
for i in range(0, NUM_TRIALS):
    minuend = random.randint(0,128)
    subtrahend = random.randint(0,128)
    diff, borrow = adder.Exec(minuend, subtrahend)
    errorCntr += (diff.int != minuend - subtrahend) and 1 or 0
print '{0} errors were found in {1} trials of the subtractor.'.format(errorCntr, NUM_TRIALS)

print '''\n\n
Waiting in an infinite loop so you can examine the results...
'''
while True:
    pass
