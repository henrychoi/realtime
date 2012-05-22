BASEDIR := ..
LOOP_FREQ ?=1
N_WORKER ?=1
TARGET := pthreadloop
LIBSRC :=
NEEDLIBS :=log timespec rtds
APP_CFLAGS := -DLOOP_FREQ=$(LOOP_FREQ) -DN_WORKER=$(N_WORKER)
APP_LDFLAGS := -lrt
include ../base.mk ##################################
debug:
	echo $(LDFLAGS)