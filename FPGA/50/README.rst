==========================================
XuLA-50 FPGA Design Examples
==========================================

Each of these directories contains a complete Xilinx ISE project for the XuLA-50 board.
(Go to the ``200`` subdirectory for a more complete collection of projects.
You can recompile them for the XuLA-50 board by changing the **Device** field in the **Design Properties**
to ``XC3S50A``.)

    fintf_jtag/:
        This design is used by GXSLOAD when it needs to read or write the contents of the
        serial flash configuration memory on the XuLA board.

    fintf_jtag_new/:
        This design is used by the Python version of XSLOAD when it needs to read or write 
        the contents of the serial flash configuration memory on the XuLA board.

    ramintfc_jtag/:
        This design is used by GXSLOAD when it needs to read or write the contents of the
        SDRAM on the XuLA board.

    ramintfc_jtag_new/:
        This design is used by the Python version of XSLOAD when it needs to read or write 
        the contents of the SDRAM on the XuLA board.

    test_board_jtag/:
        This design is used by GXSTEST to test the SDRAM and report the success or failure
        through the JTAG and USB links.

    test_board_jtag_new/:
        This design is used by the Python version of XSTEST to test the SDRAM and report 
        the success or failure through the JTAG and USB links.
