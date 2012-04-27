# Invoke with this make command:
# make LOOP_FREQ=<1 to 1000> N_CPU=<1 to 16>
LOOP_FREQ ?=1
N_WORKER ?=2
TARGET := jitter
LIBSRC :=
APP_CFLAGS := -I../timespec -DLOOP_FREQ=$(LOOP_FREQ) -DN_WORKER=$(N_WORKER)
APP_LDFLAGS := -L../timespec -ltimespec -pthread -lrt
include ../base.mk ##################################
