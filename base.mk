CC := gcc
THIRDPARTY :=../../ThirdParty
CUNIT :=$(THIRDPARTY)/CUnit-2.1-2/CUnit

LIB :=lib$(TARGET).a
TEST :=test_$(TARGET)
_OBJECTS :=$(patsubst %, %.o, $(TARGET) $(LIBSRC))

CFLAGS := -g $(APP_CFLAGS)
LDFLAGS := -Wno-pointer-to-int-cast -I$(CUNIT)/Headers\
	-static -L$(CUNIT)/Sources/.libs -lcunit -L. -l$(TARGET) $(APP_LDFLAGS)

all: $(TEST)
$(TEST): $(TEST).c $(LIB)
	gcc $(CFLAGS) -o $@ $^ $(LDFLAGS)
$(LIB): $(_OBJECTS)
	ar -rs $@ $^
%.s: %.c
	$(CC) -S $(CFLAGS) $^ $(LDFLAGS)
clean:;rm -f $(TEST) $(LIB) $(_OBJECTS)
.PHONY: clean

# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed
