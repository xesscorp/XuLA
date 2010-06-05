# Manually-generated makefile.

TARGET = xsusb_boot

TOOLDIR = \mcc18
CC = $(TOOLDIR)\bin\mcc18
CCFLAGS = -fe=$(TARGET).err -w1 -p=18F4455 -I=$(TOOLDIR)\h -I=.  -scs -Opa-
LINKER = $(TOOLDIR)\bin\mplink
LINKERFLAGS = /w /x /l$(TOOLDIR)\lib $(TOOLDIR)\bin\LKR\18f4455_g.lkr /u_CRUNTIME 
MAKEHEX = $(TOOLDIR)\bin\mp2hex
MAKEDEP = makedepend
MAKEDEPFLAGS = -I$(TOOLDIR)/h -I. -o.o

OBJECT =	main.o \
			system/usb/usbmmap.o \
			system/usb/usbdrv/usbdrv.o \
			system/usb/usb9/usb9.o \
			autofiles/usbdsc.o \
			system/usb/usbctrltrf/usbctrltrf.o \
			system/usb/class/boot/boot.o \
			configbits.o

$(TARGET).hex : $(OBJECT)
	$(LINKER) $(LINKERFLAGS) $(OBJECT) /m$(TARGET).map /o$(TARGET).cof
	$(MAKEHEX) /r 0x0000-0x07FF $(TARGET).cof 

..\xsusb_jtag\xsusb_jtag.hex :
	$(MAKE) -C ../xsusb_jtag

total : $(TARGET).hex ..\xsusb_jtag\xsusb_jtag.hex
	head --lines=-1 $(TARGET).hex > total.hex
	cat ../xsusb_jtag/xsusb_jtag.hex >> total.hex

%.o : %.c
	$(CC) $(CCFLAGS) $*.c -fo=$@

depend :
	$(MAKEDEP) $(MAKEDEPFLAGS) $(subst .o,.c,$(OBJECT))

clean :
	-rm $(OBJECT) *.cof *.cod *.hex *.lst *.map

# DO NOT DELETE

main.o: \mcc18/h/p18cxxx.h system\typedefs.h
main.o: system\usb\usb_compile_time_validation.h system\usb\usb.h
main.o: autofiles\usbcfg.h system\usb\usbdefs\usbdefs_std_dsc.h
main.o: autofiles\usbdsc.h system\usb\class\boot\boot.h
main.o: system\usb\usbdefs\usbdefs_ep0_buff.h system\usb\usbmmap.h
main.o: system\usb\usbdrv\usbdrv.h system\usb\usbctrltrf\usbctrltrf.h
main.o: system\usb\usb9\usb9.h
system/usb/usbmmap.o: system\typedefs.h system\usb\usb.h autofiles\usbcfg.h
system/usb/usbmmap.o: system\usb\usbdefs\usbdefs_std_dsc.h autofiles\usbdsc.h
system/usb/usbmmap.o: system\usb\class\boot\boot.h
system/usb/usbmmap.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usbmmap.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system/usb/usbmmap.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usbmmap.o: system\usb\usb9\usb9.h
system/usb/usbdrv/usbdrv.o: \mcc18/h/p18cxxx.h system\typedefs.h
system/usb/usbdrv/usbdrv.o: system\usb\usb.h autofiles\usbcfg.h
system/usb/usbdrv/usbdrv.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/usbdrv/usbdrv.o: autofiles\usbdsc.h system\usb\class\boot\boot.h
system/usb/usbdrv/usbdrv.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usbdrv/usbdrv.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system/usb/usbdrv/usbdrv.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usbdrv/usbdrv.o: system\usb\usb9\usb9.h io_cfg.h
system/usb/usb9/usb9.o: \mcc18/h/p18cxxx.h system\typedefs.h system\usb\usb.h
system/usb/usb9/usb9.o: autofiles\usbcfg.h
system/usb/usb9/usb9.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/usb9/usb9.o: autofiles\usbdsc.h system\usb\class\boot\boot.h
system/usb/usb9/usb9.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usb9/usb9.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system/usb/usb9/usb9.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usb9/usb9.o: system\usb\usb9\usb9.h io_cfg.h
autofiles/usbdsc.o: system\typedefs.h system\usb\usb.h autofiles\usbcfg.h
autofiles/usbdsc.o: system\usb\usbdefs\usbdefs_std_dsc.h autofiles\usbdsc.h
autofiles/usbdsc.o: system\usb\class\boot\boot.h
autofiles/usbdsc.o: system\usb\usbdefs\usbdefs_ep0_buff.h
autofiles/usbdsc.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
autofiles/usbdsc.o: system\usb\usbctrltrf\usbctrltrf.h system\usb\usb9\usb9.h
system/usb/usbctrltrf/usbctrltrf.o: \mcc18/h/p18cxxx.h system\typedefs.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usb.h autofiles\usbcfg.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/usbctrltrf/usbctrltrf.o: autofiles\usbdsc.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\class\boot\boot.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbmmap.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbdrv\usbdrv.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usb9\usb9.h
system\usb\class\boot\boot.o: \mcc18/h/p18cxxx.h system\typedefs.h
system\usb\class\boot\boot.o: system\usb\usb.h autofiles\usbcfg.h
system\usb\class\boot\boot.o: system\usb\usbdefs\usbdefs_std_dsc.h
system\usb\class\boot\boot.o: autofiles\usbdsc.h system\usb\class\boot\boot.h
system\usb\class\boot\boot.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system\usb\class\boot\boot.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system\usb\class\boot\boot.o: system\usb\usbctrltrf\usbctrltrf.h
system\usb\class\boot\boot.o: system\usb\usb9\usb9.h io_cfg.h
