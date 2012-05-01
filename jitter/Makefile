# Invoke with this make command:
# make LOOP_FREQ=<1 to 1000> N_CPU=<1 to 16>
LOOP_FREQ ?=1
N_WORKER ?=1
TARGET := jitter
LIBSRC :=
NEEDLIBS := timespec rtdb
APP_CFLAGS := -DLOOP_FREQ=$(LOOP_FREQ) -DN_WORKER=$(N_WORKER)
APP_LDFLAGS := -pthread -lrt
include ../base.mk ##################################
debug:
	echo $(LDFLAGS)