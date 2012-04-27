# Invoke with this make command:
# make DURATION=<number between 1 and 60> FREQ=<1 to 1000> N_CPU=<1 to 16>
DURATION ?=60
LOOP_FREQ ?=1
N_CPU ?=1
TARGET := jitter
LIBSRC :=
APP_CFLAGS := -I../timespec \
	-DTEST_DURATION=$(DURATION) -DLOOP_FREQ=$(LOOP_FREQ) -DN_CPU=$(N_CPU)
APP_LDFLAGS := -L../timespec -ltimespec -pthread -lrt
include ../base.mk ##################################

