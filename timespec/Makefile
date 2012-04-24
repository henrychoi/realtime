TARGET=timespec
LIB=lib$(TARGET).a
TEST=test_$(TARGET)
LIBSRC=
THIRDPARTY=../../ThirdParty
CUNIT=$(THIRDPARTY)/CUnit-2.1-2/CUnit

_OBJECTS=$(patsubst %, %.o, $(TARGET) $(LIBSRC))

# Rules ##################################
all: $(TEST)
debug:
	echo $(_OBJECTS)
$(TEST): $(TEST).o $(LIB)
	gcc -static -o $@ $^ -L$(CUNIT)/Sources/.libs -lcunit -L. -l$(TARGET)
# Alternative rule would be
# ld -static -o $@ $^\
#        -L`gcc -print-file-name=` \
#        /usr/lib/crt1.o /usr/lib/crti.o /usr/lib/crtn.o -lc -lgcc

$(LIB): $(_OBJECTS)
	ar -rs $@ $^
%.o: %.c
	gcc -c -I$(CUNIT)/Headers $< -o $@

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
