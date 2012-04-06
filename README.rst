==========================================
XuLA FPGA Board Repository
==========================================

----------------------------------------------------
Where you'll find *everything* XuLA-related!
----------------------------------------------------

This repo integrates everything for the XuLA FPGA board into one place:

    pcb/:
        Here's where you'll find the schematic and PCB layout stored as Eagle 5 files.
        
    fmw/:
        This contains the firmware for the microcontroller that manages the XuLA USB interface.
        
            boot/:
                This is the boot code that manages the reflashing of the uC firmware over the USB link.
                
            user/:
                This is the code that runs during normal operations of the XuLA board.
                It manages the interface between the FPGA and the USB link.
                
    FPGA/:
        All the example FPGA designs for the XuLA are stored in here.
        
    docs/:
        Look in here for the source of the XuLA manual and other supporting documentation.
        
    misc/:
        This is a random, grab-bag of stuff.
                