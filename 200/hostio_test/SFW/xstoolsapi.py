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
This file provides an interface between the XSTOOLs API DLL and the
rest of the Python code.
'''

import os
from ctypes import *

# Load the xstoolsApi DLL that provides access to the XuLA board.
print os.getcwd()
xstoolsApi = cdll.LoadLibrary(os.path.join(os.getcwd(), 'XstoolsApi.dll'))

# Provide shorter names for the XSTOOLs API subroutines.
MemInit = xstoolsApi.XsMemInit
MemWrite = xstoolsApi.XsMemWrite
MemRead = xstoolsApi.XsMemRead
DutInit = xstoolsApi.XsDutInit
DutWrite = xstoolsApi.XsDutWrite
DutRead = xstoolsApi.XsDutRead

# Create prototypes so the Python interpreter can detect function invocation errors.
MemInit.argtypes = [c_uint, c_uint, POINTER(c_uint), POINTER(c_uint)]
MemWrite.argtypes = [c_void_p, c_uint, POINTER(c_ulonglong), c_uint]
MemRead.argtypes = [c_void_p, c_uint, POINTER(c_ulonglong), c_uint]
DutInit.argtypes = [c_uint, c_uint, POINTER(c_uint), POINTER(c_uint)]
DutWrite.argtypes = [c_void_p, POINTER(c_ubyte), c_uint]
DutRead.argtypes = [c_void_p, POINTER(c_ubyte), c_uint]

# A little utility subroutine for printing out a list of bits with bits[0] = LSB. 
def PrintBits(bits):
    print ''.join([str(b) for b in reversed(bits)]) # Reverse bits so they get printed MSB-first.
