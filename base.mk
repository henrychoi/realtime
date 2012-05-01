CC := gcc
THIRDPARTY :=../../ThirdParty
CUNIT :=$(THIRDPARTY)/CUnit-2.1-2/CUnit

LIB :=lib$(TARGET).a
TEST :=test_$(TARGET)
_OBJECTS :=$(patsubst %, %.o, $(TARGET) $(LIBSRC))
CFLAGS := -g $(patsubst %, -I../%, $(NEEDLIBS)) $(APP_CFLAGS)
LDFLAGS := -Wno-pointer-to-int-cast -I$(CUNIT)/Headers\
	-static -L$(CUNIT)/Sources/.libs -lcunit -L. -l$(TARGET)\
	$(foreach module, $(NEEDLIBS), -L../$(module) -l$(module))\
	$(APP_LDFLAGS)

.PHONY: clean $(NEEDLIBS)
all: $(TEST)
$(TEST): $(TEST).c $(LIB) $(NEEDLIBS)
	gcc $(CFLAGS) -o $@ $(TEST).c $(LIB) $(LDFLAGS)
$(LIB): $(_OBJECTS); ar -rs $@ $^
%.s: %.c; $(CC) -S $(CFLAGS) $^ $(LDFLAGS)
clean: $(foreach module, $(NEEDLIBS), clean.$(module))
	-rm -f $(TEST) $(LIB) $(_OBJECTS) *~

clean.%:;make -C ../$(patsubst clean.%,%, $@) clean
$(NEEDLIBS):;make -C ../$@
# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed
