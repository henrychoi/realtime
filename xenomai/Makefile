BASEDIR := ..
TARGET := xenomai
LIBSRC :=
NEEDLIBS :=rtds
BUILDROOT :=$(BASEDIR)/ThirdParty/buildroot-2012.02-i386
XENOMAI :=$(BUILDROOT)/output/build/xenomai-2.6.0
KERNEL :=$(BUILDROOT)/output/build/linux-2.6.38.8
UCLIBC :=$(BUILDROOT)/output/toolchain/uClibc-0.9.32.1
APP_CFLAGS :=-I$(XENOMAI)/include -I$(KERNEL)/include/xenomai\
	-I$(XROOT)/$(CROSS)/sysroot/usr/include/xenomai
#	-I$(UCLIBC)/include
APP_LDFLAGS :=-L$(XROOT)/$(CROSS)/sysroot/usr/lib -lnative -lxenomai
include ../base.mk ##################################
