# Manually-generated makefile.

TARGET = xsusb_jtag

TOOLDIR = \mcc18
CC = $(TOOLDIR)\bin\mcc18
CCFLAGS = -fe=$(TARGET).err -w1 -p=18F4455 -I=$(TOOLDIR)\h -I=. -Ou- -Ot- -Ob- -Op- -Or- -Od- -Opa-
LINKER = $(TOOLDIR)\bin\mplink
LINKERFLAGS = /w /x /l$(TOOLDIR)\lib rm18f4455.lkr
MAKEHEX = $(TOOLDIR)\bin\mp2hex
MAKEDEP = makedepend
MAKEDEPFLAGS = -I$(TOOLDIR)/h -I. -o.o

OBJECT =	main.o \
			system/usb/usbmmap.o \
			system/usb/usbdrv/usbdrv.o \
			system/usb/usb9/usb9.o \
			autofiles/usbdsc.o \
			system/usb/usbctrltrf/usbctrltrf.o \
			user/user.o \
			system/usb/class/generic/usbgen.o \
			configbits.o
			
$(TARGET).hex : $(OBJECT)
	$(LINKER) $(LINKERFLAGS) $(OBJECT) /m$(TARGET).map /o$(TARGET).cof
	$(MAKEHEX) /r 0x000800-0xFFFFFF $(TARGET).cof 

..\xsusb_boot\xsusb_boot.hex :
	$(MAKE) -C ../xsusb_boot

total : $(TARGET).hex ..\xsusb_boot\xsusb_boot.hex
	head --lines=-1 ../xsusb_boot/xsusb_boot.hex > total.hex
	cat $(TARGET).hex >> total.hex

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
main.o: autofiles\usbdsc.h system\usb\usbdefs\usbdefs_ep0_buff.h
main.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
main.o: system\usb\usbctrltrf\usbctrltrf.h system\usb\usb9\usb9.h
system/usb/usbmmap.o: system\typedefs.h system\usb\usb.h autofiles\usbcfg.h
system/usb/usbmmap.o: system\usb\usbdefs\usbdefs_std_dsc.h autofiles\usbdsc.h
system/usb/usbmmap.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usbmmap.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system/usb/usbmmap.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usbmmap.o: system\usb\usb9\usb9.h
system/usb/usbdrv/usbdrv.o: \mcc18/h/p18cxxx.h system\typedefs.h
system/usb/usbdrv/usbdrv.o: system\usb\usb.h autofiles\usbcfg.h
system/usb/usbdrv/usbdrv.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/usbdrv/usbdrv.o: autofiles\usbdsc.h
system/usb/usbdrv/usbdrv.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usbdrv/usbdrv.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system/usb/usbdrv/usbdrv.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usbdrv/usbdrv.o: system\usb\usb9\usb9.h io_cfg.h
system/usb/usb9/usb9.o: \mcc18/h/p18cxxx.h system\typedefs.h system\usb\usb.h
system/usb/usb9/usb9.o: autofiles\usbcfg.h
system/usb/usb9/usb9.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/usb9/usb9.o: autofiles\usbdsc.h
system/usb/usb9/usb9.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usb9/usb9.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
system/usb/usb9/usb9.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usb9/usb9.o: system\usb\usb9\usb9.h io_cfg.h
autofiles/usbdsc.o: system\typedefs.h system\usb\usb.h autofiles\usbcfg.h
autofiles/usbdsc.o: system\usb\usbdefs\usbdefs_std_dsc.h autofiles\usbdsc.h
autofiles/usbdsc.o: system\usb\usbdefs\usbdefs_ep0_buff.h
autofiles/usbdsc.o: system\usb\usbmmap.h system\usb\usbdrv\usbdrv.h
autofiles/usbdsc.o: system\usb\usbctrltrf\usbctrltrf.h system\usb\usb9\usb9.h
system/usb/usbctrltrf/usbctrltrf.o: \mcc18/h/p18cxxx.h system\typedefs.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usb.h autofiles\usbcfg.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/usbctrltrf/usbctrltrf.o: autofiles\usbdsc.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbmmap.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbdrv\usbdrv.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/usbctrltrf/usbctrltrf.o: system\usb\usb9\usb9.h
user/user.o: \mcc18/h/p18cxxx.h \mcc18/h/usart.h \mcc18/h/string.h
user/user.o: \mcc18/h/stddef.h \mcc18/h/delays.h system\typedefs.h
user/user.o: system\usb\usb.h autofiles\usbcfg.h
user/user.o: system\usb\usbdefs\usbdefs_std_dsc.h autofiles\usbdsc.h
user/user.o: system\usb\usbdefs\usbdefs_ep0_buff.h system\usb\usbmmap.h
user/user.o: system\usb\usbdrv\usbdrv.h system\usb\usbctrltrf\usbctrltrf.h
user/user.o: system\usb\usb9\usb9.h io_cfg.h
system/usb/class/generic/usbgen.o: \mcc18/h/p18cxxx.h system\typedefs.h
system/usb/class/generic/usbgen.o: system\usb\usb.h autofiles\usbcfg.h
system/usb/class/generic/usbgen.o: system\usb\usbdefs\usbdefs_std_dsc.h
system/usb/class/generic/usbgen.o: autofiles\usbdsc.h
system/usb/class/generic/usbgen.o: system\usb\usbdefs\usbdefs_ep0_buff.h
system/usb/class/generic/usbgen.o: system\usb\usbmmap.h
system/usb/class/generic/usbgen.o: system\usb\usbdrv\usbdrv.h
system/usb/class/generic/usbgen.o: system\usb\usbctrltrf\usbctrltrf.h
system/usb/class/generic/usbgen.o: system\usb\usb9\usb9.h
