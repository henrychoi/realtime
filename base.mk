CC := gcc
THIRDPARTY :=$(BASEDIR)/../ThirdParty
CUNIT :=$(THIRDPARTY)/CUnit-2.1-2/CUnit

LIB :=lib$(TARGET).a
TEST :=test_$(TARGET)
_objects :=$(patsubst %, %.o, $(TARGET) $(LIBSRC))
CFLAGS := -g $(patsubst %, -I$(BASEDIR)/%, $(NEEDLIBS)) $(APP_CFLAGS)
LDFLAGS := -Wno-pointer-to-int-cast -Wno-int-to-pointer_cast\
	-I$(CUNIT)/Headers\
	-static -L$(CUNIT)/Sources/.libs -lcunit -L. -l$(TARGET)\
	$(foreach module, $(NEEDLIBS), -L$(BASEDIR)/$(module) -l$(module))\
	$(APP_LDFLAGS)

.PHONY: clean
all: $(TEST)
$(TEST): $(TEST).c $(LIB) $(NEEDLIBS)
	gcc $(CFLAGS) -o $@ $(TEST).c $(LIB) $(LDFLAGS)
$(LIB): $(_objects); ar -rs $@ $^
%.s: %.c; $(CC) -S $(CFLAGS) $^ $(LDFLAGS)
clean: $(foreach module, $(NEEDLIBS), clean.$(module))
	-rm -f $(TEST) $(LIB) $(_objects) *~

clean.%:;make -C $(BASEDIR)/$(patsubst clean.%,%, $@) clean
$(NEEDLIBS):;make -C $(BASEDIR)/$@
# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed
