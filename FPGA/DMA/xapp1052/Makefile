obj-m := xbmd.o
KVERSION := $(shell uname -r)
module:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) modules
app:
	gtk-builder-convert xbmd_app.glade xbmd_app.xml
	g++ -Wall -g -o xbmd_app cfg.cpp bmd.cpp xbmd_ep.cpp xbmd_main.cpp `pkg-config --cflags --libs gtk+-3.0 --libs libglade-2.0` -export-dynamic
all: app module

clean:
	make -C /lib/modules/$(KVERSION)/build M=$(PWD) clean
