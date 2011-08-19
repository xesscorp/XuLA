FPGA <=> PC HOST BIDIRECTIONAL COMMUNICATION
    One of the hardest things to do with any FPGA board is to get data from
    the board back to a PC where it can be post-processed and stored. The
    second-hardest thing is to control the FPGA by sending commands and data
    from the PC.

    The HostIo package tries to make communicating between the FPGA and the
    PC easier. It consists of three things:

    *   HDL modules you can include in your FPGA design that allow the PC to
        inject signals into your circuitry and let your circuitry send
        signals back to the PC through the JTAG port of the FPGA.

    *   Firmware for the microcontroller on the XuLA board that manages the
        passing of data between the JTAG and USB ports.

    *   A software library that interfaces the USB port of the XuLA board to
        C, C++ or Python code running on the host PC.

  HDL Modules
    The HDL modules are in the HostIo.vhd file in the XuLA_lib directory.
    There are currently three modules for use in a design:

    * BscanToHostIo
        This module connects the Xilinx BSCAN primitive to one or more
        HostIo modules. It transfers JTAG status, serial data and
        shift-clock signals from the host PC to all the other HostIo modules
        and returns a data signal to the PC that is the logical-OR of the
        serial data outputs of the other HostIo modules. You must include
        this module in your design if you want to use any of the other
        HostIo modules.

    * HostIoToDut
        This module goes between the BscanToHostIo module and a
        device-under-test (DUT) which can be any piece of application logic
        circuitry in the FPGA. This module parallelizes serial data and
        applies it to the inputs of the DUT, and it collects the DUT outputs
        and sends them back as a serial data stream. This module also
        outputs a clock pulse everytime it receives a new set of DUT inputs
        and this can be used to trigger the operation of the DUT, if
        desired.

        This module accepts a generic parameter that defines its eight-bit
        identifier. This identifier is used to select the bits intended for
        this module from the serial data stream output by the BscanToHostIo
        module. Each module instantiated in an FPGA design must have a
        unique identifier.

    * HostIoToRam
        This module goes between the BscanToHostIo module and any RAM or
        register-like piece of application logic circuitry in the FPGA. This
        module parallelizes a serial address and applies it to the RAM.
        Then, if a write operation was requested, it parallelizes serial
        data, places it on the RAM data bus and pulses the RAM write-enable
        input. Or, if a read operation was requested, it pulses the RAM
        read-enable input, gathers up the data from the RAM data bus, and
        sends it back as serial data. A slow device can de-assert an
        operation-done input that halts the operation of this module until
        the device completes the read or write operation. After each read or
        write operation, the address is incremented.

        This module also accepts a clock input from the application logic
        side so the read and write operations will be synchronized with the
        application logic.

        This module accepts a generic parameter that defines its eight-bit
        identifier. This identifier is used to select the bits intended for
        this module from the serial data stream output by the BscanToHostIo
        module. Each module instantiated in an FPGA design must have a
        unique identifier.

  Microcontroller Firmware
        The microcontroller firmware accepts packets of JTAG commands from
        the host PC over the USB link and sends them to the FPGA. It also
        accepts JTAG data from the FPGA and packages it into USB packets
        that are returned to the PC.

        As of this date (08/17/2011), the XuLA board factory-installed
        firmware does not support the JTAG commands needed to use the HostIo
        modules. Therefore, you must upgrade the firmware using the XuLA
        Firmware Update command placed in the Windows Start menu when you
        installed the XSTOOLs software. (Just attach your XuLA board to a
        USB port and execute this command to upgrade the firmware.)

  Host PC Software Library
        XstoolsApi.dll is the dynamic link library containing the
        subroutines for initializing and communicating with the HostIo
        modules in the FPGA. A list of the subroutines can be found in the
        XstoolsApi.h file.

Design Example
        A complete design example is provided that configures the FPGA with
        circuitry that can be probed through the HostIo modules by a program
        running on a host PC.

  FPGA Directory
        The FPGA directory contains an FPGA design built from three
        components:

        * A 32-bit register.
        * A 1024 x 16 block RAM (BRAM).
        * A four-bit up/down counter.

        The register and BRAM are each connected to their own HostIoToRam
        module, and the counter is connected to a HostIoToDut module.

  SFW Directory
        The SFW directory contains the hostio_test.exe executable that
        performs the following operations:

        *   It iteratively writes, reads and compares the 32-bit register
            with 1000 random values and reports if any mismatches between
            the read and written values were seen.

        *   It writes the BRAM with 1024 random values, reads them back and
            reports if any mismatches between the read and written values
            were seen.

        *   It increments the four-bit counter sixteen times, then
            decrements it sixteen times, reporting the counter's value after
            each operation.

        The other files in this directory are:

        *   hostio_test.py contains the Python source for the executable.
            You can execute this file directly if you have a Python
            interpreter installed on your PC.

        *   hostio_test.spec contains the information for compiling the
            Python source into an executable using the PyInstaller tool.

        *   XstoolsApi.dll is the dynamic link library containing the
            subroutines for initializing and communicating with the HostIo
            modules in the FPGA.

        *   XstoolsApi.h lists the subroutines found in the DLL.

        *   xstoolsapi.py is a Python interface between the hostio_test.py
            program and the XstoolsApi.dll DLL.

  Running the Design Example
        1.  Plug your XuLA board into a USB port on your PC.

        2.  Upgrade the XuLA firmware if you haven't already done so.

        3.  Download the hostio_test.bit bitstream to the FPGA on the XuLA
            board using GXSLOAD.

        4.  Execute the hostio_test.exe program. It will show the results of
            the tests described above.

  Modifying the Design Example
        Here are a couple of simple ideas to try:

        *   Modify the counter to increment/decrement by three. Download the
            new design to the XuLA board and run hostio_test.exe again. Note
            the change in the counter values that are displayed.

        *   Modify the register portion of the hostio_test design so that it
            stores the given value plus one. Then run hostio_test.exe again.
            It should report 1000 errors in reading/writing the register
            because the value read from the register no longer matches the
            value that was written.

        *   Install Python 2.7 and the ctypes module so you can run the
            hostio_text.py program directly without the need to compile it.
            Then modify the Python source so the value read from the
            register is decremented before comparing it to the value that
            was written. Run the modified Python program with the modified
            FPGA design in the XuLA board. Now the errors reading/writing
            the register should be gone.

