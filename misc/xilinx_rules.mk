#-------------------------------------------------------------------
# Company       : XESS Corp.
# Engineer      : Dave Vanden Bout
# Creation Date : 05/16/2006
# Copyright     : 2005-2006, XESS Corp
# Tool Versions : make 3.79.1, perl 5.8.8, WebPACK 8.1.03i
#
# Description:
#    This makefile contains the rules that move the HDL files through
#    the Xilinx WebPACK/ISE synthesizer, place & route and bitstream 
#    generation processes to produce the final bitstream file.
#
# Revision:
#    1.0.4
#
# Additional Comments:
#    This file is normally included in another makefile using the
#    `include' directive.  Usually this file is placed in the 
#    /usr/local/include directory so make can find it automatically.
#
#    The makefile targets are:
#        config: Creates bit/svf file for FPGA/CPLD.
#        svf:    Directly creates bit file for FPGA.
#        bit:    Directly creates svf file for CPLD.
#        mcs:    Creates Intel MCS file from bit file.
#        exo:    Creates Motorola EXO file from bit file.
#        timing: Creates timing report for FPGA (not CPLD).
#        clean:  Cleans temporary files created during build process.
#        distclean: Clean and also remove timing report.
#        maintainer-clean: Distclean and also remove bit/svf files.
#        nice:   beautify the HDL source code
#
#    1.0.4:
#        Added .cfg prefix to trigger the xtclsh tool flow
#        for compiling bitstreams in ISE 13.
#    1.0.3:
#        Modified to support ISE 9 project directory structure.
#    1.0.2:
#        Added more file types for removal during cleaning.
#    1.0.1:
#        Added 'nice' target.
#    1.0.0
#        Initial revision.
#-------------------------------------------------------------------



#
# Paths to utilities.
#

# Standard OS utilities.  These are for DOS.  Set them for your particular OS.
RM                 := rm -rf
RMDIR              := rmdir /s /q
MKDIR              := mkdir
ECHO               := echo
EMACS              := /bin/emacs-21.3/bin/emacs

# These are Perl script files that perform some simple operations.
UTILITY_DIR        := C:/BIN/
SET_OPTION_VALUES  := perl $(UTILITY_DIR)set_option_values.pl
GET_OPTION_VALUES  := perl $(UTILITY_DIR)get_option_values.pl
GET_PROJECT_FILES  := perl $(UTILITY_DIR)get_project_files.pl



#
# Flags and option values that control the behavior of the Xilinx tools.
# You can override these values in the makefile that includes this one.
# Otherwise, the default values will be set as shown below.
#

# Unless otherwise specified, the name of the design and the top-level
# entity are derived from the name of the directory that contains the design.
DIR_SPACES  := $(subst /, ,$(CURDIR))
DIR_NAME    := $(word $(words $(DIR_SPACES)), $(DIR_SPACES))
DESIGN_NAME ?= $(DIR_NAME)
TOP_NAME    ?= $(DESIGN_NAME)

# Extract the part identifier from the project .npl file.
PART_TYPE        ?=            $(shell $(GET_OPTION_VALUES) $(DESIGN_NAME).npl DEVICE)
PART_SPEED_GRADE ?= $(subst -,,$(shell $(GET_OPTION_VALUES) $(DESIGN_NAME).npl DEVSPEED))
PART_PACKAGE     ?=            $(shell $(GET_OPTION_VALUES) $(DESIGN_NAME).npl DEVPKG)
PART             ?= $(PART_TYPE)-$(PART_SPEED_GRADE)-$(PART_PACKAGE)

# This variable will be non-empty if the design is targeted to an XC9500 CPLD.
IS_CPLD = $(findstring xc95,$(PART))

# Flags common to both FPGA and CPLD design flow.
INTSTYLE         ?= -intstyle silent      # call Xilinx tools in silent mode
XST_FLAGS        ?= $(INTSTYLE)           # most synthesis flags are specified in the .xst file
UCF_FILE         ?= $(DESIGN_NAME).ucf    # constraint/pin-assignment file
NGDBUILD_FLAGS   ?= $(INTSTYLE) -dd _ngo  # ngdbuild flags
NGDBUILD_FLAGS += $(if $(UCF_FILE),-uc,) $(UCF_FILE)         # append the UCF file option if it is specified 

# Flags for FPGA-specific tools.  These were extracted by looking in the
# .cmd_log file after compiling the design with the WebPACK/ISE GUI.
MAP_FLAGS        ?= $(INTSTYLE) -cm area -pr b -k 4 -c 100 -tx off
PAR_FLAGS        ?= $(INTSTYLE) -w -ol std -t 1
TRCE_FLAGS       ?= $(INTSTYLE) -e 3 -l 3
BITGEN_FLAGS     ?= $(INTSTYLE)           # most bitgen flags are specified in the .ut file
PROMGEN_FLAGS    ?= -u 0                  # flags that control the MCS/EXO file generation

# Flags for CPLD-specific tools.  These were extracted by looking in the
# .cmd_log file after compiling the design with the WebPACK/ISE GUI.
CPLDFIT_FLAGS    ?= -ofmt vhdl -optimize speed -htmlrpt -loc on -slew fast -init low -inputs 54 -pterms 25 -unused float -power std -terminate keeper
SIGNATURE        ?= $(DESIGN_NAME)        # JTAG-accessible signature stored in the CPLD
HPREP6_FLAGS     ?= -s IEEE1149           # hprep flags
HPREP6_FLAGS     += $(if $(SIGNATURE),-n,) $(SIGNATURE)  # append signature if it is specified 

# Determine the version of Xilinx ISE that is being used by reading it from the
# readme.txt file in the top-level directory of the Xilinx software.
ISE_VERSION ?= $(shell grep -m 1 -o -P "ISE\s*[0-9]+" %XILINX%/readme.txt | grep -m 1 -P -o "[0-9]+")
ifeq ($(ISE_VERSION),6)
	PROJNAV_DIR ?= __projnav
else
ifeq ($(ISE_VERSION),7)
	PROJNAV_DIR ?= __projnav
else
	PROJNAV_DIR ?= .
endif
endif

# Select the correct tool options files that control the synthesizer
# and bitstream generator for FPGAs or CPLDs.
ifneq (,$(IS_CPLD))
	XST_CPLD_OPTIONS_FILE ?= $(PROJNAV_DIR)/$(DESIGN_NAME).xst
	IMPACT_OPTIONS_FILE   ?= _impact.cmd
	XST_OPTIONS_FILE       = $(XST_CPLD_OPTIONS_FILE)
else
	XST_FPGA_OPTIONS_FILE ?= $(PROJNAV_DIR)/$(DESIGN_NAME).xst
	BITGEN_OPTIONS_FILE   ?= $(DESIGN_NAME).ut
	XST_OPTIONS_FILE       = $(XST_FPGA_OPTIONS_FILE)
endif



#
# The following rules describe how to compile the design to an FPGA/CPLD.
#

# Get the list of VHDL and Verilog files that this design depends on by
# extracting their names from the project .prj file.  This variable is used
# by make for checking dependencies, but the synthesizer tool ignores this
# variable and uses the file list found in the .prj file.
ifeq ($(origin HDL_FILES),undefined)
  HDL_FILES       ?= $(shell $(GET_PROJECT_FILES) $(DESIGN_NAME).prj)
endif

# cleanup the source code to make it look nice
%.nice: %.vhd
	$(EMACS) -batch $< -f vhdl-beautify-buffer -f save-buffer
	$(RM) $<~

# Synthesize the HDL files into an NGC file.  This rule is triggered if
# any of the HDL files are changed or the synthesis options are changed.
%.ngc: $(HDL_FILES) $(XST_OPTIONS_FILE)
	-$(MKDIR) $(PROJNAV_DIR)
                # The .xst file containing the synthesis options is modified to 
                # reflect the design name, device, and top-level entity and stored
                # in a temporary .xst file.
	$(SET_OPTION_VALUES) $(XST_OPTIONS_FILE) \
		"set -tmpdir $(PROJNAV_DIR)" \
		"-lso $(DESIGN_NAME).lso" \
		"-ifn $(DESIGN_NAME).prj" \
		"-ofn $(DESIGN_NAME)" \
		"-p $(PART)" \
		"-top $(TOP_NAME)" \
			> $(PROJNAV_DIR)/tmp.xst
	xst $(XST_FLAGS) -ifn $(PROJNAV_DIR)/tmp.xst -ofn $*.syr

# Take the output of the synthesizer and create the NGD file.  This rule
# will also be triggered if constraints file is changed.
%.ngd: %.ngc %.ucf
	ngdbuild $(NGDBUILD_FLAGS) -p $(PART) $*.ngc $*.ngd

# Map the NGD file and physical-constraints to the FPGA to create the mapped NCD file.
%_map.ncd %.pcf: %.ngd
	map $(MAP_FLAGS) -p $(PART) -o $*_map.ncd $*.ngd $*.pcf

# Place & route the mapped NCD file to create the final NCD file.
%.ncd: %_map.ncd %.pcf
	par $(PAR_FLAGS) $*_map.ncd $*.ncd $*.pcf

# Take the final NCD file and create an FPGA bitstream file.  This rule will also be
# triggered if the bit generation options file is changed.
%.bit: %.ncd $(BITGEN_OPTIONS_FILE)
	bitgen $(BITGEN_FLAGS) -f $(BITGEN_OPTIONS_FILE) $*.ncd

# Convert a bitstream file into an MCS hex file that can be stored into Flash memory.
%.mcs: %.bit
	promgen $(PROMGEN_FLAGS) $*.bit -p mcs

# Convert a bitstream file into an EXO hex file that can be stored into Flash memory.
%.exo: %.bit
	promgen $(PROMGEN_FLAGS) $*.bit -p exo

# Fit the NGD file synthesized for the CPLD to create the VM6 file.
%.vm6: %.ngd
	cpldfit $(CPLDFIT_FLAGS) -p $(PART) $*.ngd

# Convert the VM6 file into a JED file for the CPLD.
%.jed: %.vm6
	hprep6 $(HPREP6_FLAGS) -i $*.vm6

# Convert JED file into an SVF file for the CPLD.
%.svf: %.jed $(IMPACT_OPTIONS_FILE)
	$(SET_OPTION_VALUES) $(IMPACT_OPTIONS_FILE) \
		"setCable -port svf -file \"$*.svf\"" \
		"addDevice -position 1 -file \"$*.jed\"" \
			> impactcmd.txt
	$(ECHO) "quit" >> impactcmd.txt
	impact -batch impactcmd.txt

# Use .config suffix to trigger creation of a bit/svf file
# depending upon whether an FPGA/CPLD is the target device.
%.config: $(if $(IS_CPLD),%.svf,%.bit) ;

# Use . suffix to trigger creation of a bit/svf file
# using xtclsh and .tcl file. Perl is used to edit the .tcl
# file output by ISE so it will generate a programming file
# instead of stopping after the implementation phase and for
# adding the file with the process properties.
%.cfg: %.tcl
	perl -p -e "s/set task \"Implement Design\"/set task \"Generate Programming File\"/" $*.tcl > $*-tmp1.tcl
	perl -p -e 's|(   puts "\\$$myScript. setting process properties..."\n)|$$1   source "../../process_properties.tcl"|' $*-tmp1.tcl > $*-tmp2.tcl
	xtclsh $*-tmp2.tcl rebuild_project
	-$(RM) $*-tmp1.tcl $*-tmp2.tcl

# Create the FPGA timing report after place & route.
%.twr: %.ncd %.pcf
	trce $(TRCE_FLAGS) $*.ncd -o $*.twr $*.pcf

# Use .timing suffix to trigger timing report creation.
%.timing: %.twr ;

# Preserve intermediate files.
.PRECIOUS: %.ngc %.ngd %_map.ncd %.ncd %.twr %.vm6 %.jed

# Clean up after creating the configuration file.
%.clean:
	-$(RM) *.stx *.ucf.untf *.mrp *.nc1 *.ngm *.prm *.lfp
	-$(RM) *.placed_ncd_tracker *.routed_ncd_tracker
	-$(RM) *.pad_txt *.twx *.log *.vhd~ *.dhp *.jhd *.cel
	-$(RM) *.ngr *.ngc *.ngd *.syr *.bld *.pcf
	-$(RM) *_map.mrp *_map.ncd *_map.ngm *.ncd *.pad
	-$(RM) *.par *.xpi *_pad.csv *_pad.txt *.drc *.bgn
	-$(RM) *.xml *_build.xml *.rpt *.gyd *.mfd *.pnx
	-$(RM) *.vm6 *.jed *.err *.ER result.txt tmperr.err *.bak *.vhd~
	-$(RM) *.zip *_backup *.*log *.map *.unroutes *.html
	-$(RM) *.xmsgs *.jou *.ptwx *.xst *.xrpt *.xwbt *.prj *.tpl
	-$(RM) impactcmd.txt
	-$(RM) xst _xmsgs _ngo *_html *_xdb templates iseconfig ipcore_dir __projnav

# Clean for distribution.
%.distclean: %.clean
	-$(RM) *.twr

# Clean everything.
%.maintainer-clean: %.distclean
	-$(RM) *.bit *.svf *.exo *.mcs



#
# Default targets for FPGA/CPLD compilations.
#

config          : $(DESIGN_NAME).config
bit             : $(DESIGN_NAME).bit
svf             : $(DESIGN_NAME).svf
mcs             : $(DESIGN_NAME).mcs
exo             : $(DESIGN_NAME).exo
timing          : $(DESIGN_NAME).timing
clean           : $(DESIGN_NAME).clean
distclean       : $(DESIGN_NAME).distclean
maintainer-clean: $(DESIGN_NAME).maintainer-clean
nice            : $(subst .vhd,.nice,$(HDL_FILES))

