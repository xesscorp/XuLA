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

USB_ID = 0   # This is the USB index for the XuLA board connected to the host PC.


print '''\n\n\n
##################################################################
# Test the single register in the FPGA hostio_test circuit.
##################################################################
'''
REG_ID = 1 # This is the identifier for the single register in the FPGA.
addrWidth = c_uint() # Stores the address width of the register.
dataWidth = c_uint() # Stores the data width of the register.

# Get a handle for the register in the FPGA.
reg = MemInit(USB_ID, REG_ID, byref(addrWidth), byref(dataWidth))
if reg == 0:
    print "Couldn't get a handle for the register!"
    sys.exit()

# Create variables for reading/writing the register.
addr = c_uint(0) # Set the address to zero.
writeData = c_ulonglong() # Stores the data to write to the register.
readData = c_ulonglong() # Stores the data read back from the register.

# Repeatedly write & read the register.
numTrials = 1000
errorCntr = 0
for i in range(0,numTrials):
    writeData.value = random.randint(0,2**(dataWidth.value-1)) # Generate a random value.
    MemWrite(reg,addr,byref(writeData),1) # Write it to the register.
    MemRead(reg,addr,byref(readData),1) # Read back the register contents.
    if readData.value != writeData.value: # Compare value read back to value written.
        errorCntr += 1 # Record error if value read back doesn't match value written.
print "Register was written and read back {0} times and {1} errors occurred.".format(numTrials,errorCntr)


print '''\n\n\n
##################################################################
# Test the block RAM in the FPGA hostio_test circuit.
##################################################################
'''
BRAM_ID = 2 # This is the identifier for the BRAM in the FPGA.
addrWidth = c_uint() # Stores the address width of the BRAM.
dataWidth = c_uint() # Stores the data width of the BRAM.

# Get a handle for the BRAM in the FPGA.
bram = MemInit(USB_ID, BRAM_ID, byref(addrWidth), byref(dataWidth))
if bram == 0:
    print "Couldn't get a handle for the block RAM!"
    sys.exit()

# Create variables and arrays for reading/writing the BRAM.
addr = c_uint() # Stores the BRAM address.
bramSize = 2**addrWidth.value
wrBram = (c_ulonglong * bramSize)()
rdBram = (c_ulonglong * bramSize)()

# Generate an array of random data values.
for i in range(0, bramSize):
    wrBram[i] = random.randint(0,2**(dataWidth.value-1)-1)

MemWrite(bram,0,wrBram,bramSize) # Write array of random numbers to BRAM.
MemRead(bram,0,rdBram,bramSize) # Read back contents of BRAM.

# Compare the values read back from the BRAM with the values written to it.
errorCntr = 0
for i in range(0,bramSize):
    if rdBram[i] != wrBram[i]:
        errorCntr += 1

# Report any comparison errors.        
print "{0} BRAM locations were written and read back and {1} errors were found.".format(bramSize,errorCntr)


print '''\n\n\n
##################################################################
# Test the four-bit counter in the FPGA hostio_test circuit.
##################################################################
'''
CNTR_ID = 3  # This is the identifier for the counter in the FPGA.
numInputs = c_uint()  # Stores the number of inputs to the counter.
numOutputs = c_uint()  # Stores the number of outputs from the counter.

# Get a handle for the counter in the FPGA.
cntr = DutInit(USB_ID, CNTR_ID, byref(numInputs), byref(numOutputs))
if cntr == 0:
    print "Couldn't get a handle for the counter!"
    sys.exit()

# Create arrays for the inputs/outputs to/from the counter.
inputs = (c_ubyte * numInputs.value)()
outputs = (c_ubyte * numOutputs.value)()

# These are the settings for the control input of the counter.
INCREMENT = 1
DECREMENT = 0

print 'First, we increment:'
inputs[0] = INCREMENT
for i in range(0, 16):
    DutWrite(cntr, inputs, numInputs) # Write the control signal and pulse the counter clock input.
    DutRead(cntr, outputs, numOutputs) # Read the new value of the counter.
    PrintBits(outputs) # Print the counter bits.

print '\nThen, we decrement:'
inputs[0] = DECREMENT
for i in range(0, 16):
    DutWrite(cntr, inputs, numInputs)
    DutRead(cntr, outputs, numOutputs)
    PrintBits(outputs)

print '\n\n\nWaiting in infinite loop so you can examine the results...'
while(True):
    pass