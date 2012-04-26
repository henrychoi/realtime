# Invoke with this make command:
# make DURATION=<number between 1 and 60> FREQ=<1 to 1000>
TARGET=jitter
LIB=lib$(TARGET).a
TEST=test_$(TARGET)
LIBSRC=
THIRDPARTY=../../ThirdParty
CUNIT=$(THIRDPARTY)/CUnit-2.1-2/CUnit

_OBJECTS=$(patsubst %, %.o, $(TARGET) $(LIBSRC))

# Rules ##################################
all: $(TEST)
$(TEST): $(TEST).c #$(LIB)
	gcc -g -static -mtune=core2 -o $@ $^ \
	-Wno-pointer-to-int-cast \
	-DTEST_DURATION=$(DURATION) -DLOOP_FREQ=$(FREQ) \
	-I$(CUNIT)/Headers -I../timespec \
	-L$(CUNIT)/Sources/.libs -lcunit -L../timespec -ltimespec -pthread -lrt
debug: $(TEST).c #$(TARGET).c
	gcc -S -g $^ \
	-Wno-pointer-to-int-cast \
	-DTEST_DURATION=$(DURATION) -DLOOP_FREQ=$(FREQ) \
	-I$(CUNIT)/Headers -I../timespec

$(LIB): $(_OBJECTS)
	ar -rs $@ $^
%.o: %.c
	gcc -c -g $< -o $@

.PHONY: clean
clean:
	rm -f $(TEST) $(LIB) $(_OBJECTS)

# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed

# If you don't mind compiling all sources each time, this is a much
# simpler rule
#$(TEST): $(_SOURCES) $(_HEADERS)
#	gcc $(CCFLAGS) $(_SOURCES) -o $@ $(LDFLAGS)
