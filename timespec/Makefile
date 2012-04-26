TARGET=timespec
LIB=lib$(TARGET).a
TEST=test_$(TARGET)
LIBSRC=
THIRDPARTY=../../ThirdParty
CUNIT=$(THIRDPARTY)/CUnit-2.1-2/CUnit

_OBJECTS=$(patsubst %, %.o, $(TARGET) $(LIBSRC))

# Rules ##################################
all: $(TEST)
$(TEST): $(TEST).c $(LIB)
	gcc -g -static -I$(CUNIT)/Headers -o $@ $^ \
	-Wno-pointer-to-int-cast \
	-L$(CUNIT)/Sources/.libs -lcunit -L. -l$(TARGET)
debug: $(TEST).c #$(TARGET).c
	gcc -S -g $^ \
	-mtune=core2 -Wno-pointer-to-int-cast \
	-I$(CUNIT)/Headers -I../timespec

$(LIB): $(_OBJECTS)
	ar -rs $@ $^
%.o: %.c
	gcc -c -g $< -o $@

.PHONY: clean debug
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
