# Invoke with this make command:
# make DURATION=<number between 1 and 60> FREQ=<1 to 1000>

# These must be specified before including the rules.mk!
TARGET=jitter
LIBSRC=
DURATION ?=60
LOOP_FREQ ?=1
N_CPU ?=1
include ../base.mk ##################################

$(TEST): $(TEST).c #$(LIB)
	gcc -g -static -o $@ $^ \
	-Wno-pointer-to-int-cast \
	-DTEST_DURATION=$(DURATION) -DLOOP_FREQ=$(FREQ) -DN_CPU=$(N_CPU)\
	-I$(CUNIT)/Headers -I../timespec \
	-L$(CUNIT)/Sources/.libs -lcunit -L../timespec -ltimespec -pthread -lrt
debug: $(TEST).c #$(TARGET).c
	gcc -S -g $^ \
	-Wno-pointer-to-int-cast \
	-DTEST_DURATION=$(DURATION) -DLOOP_FREQ=$(FREQ) \
	-I$(CUNIT)/Headers -I../timespec