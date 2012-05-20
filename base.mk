ifdef CROSS
  CC :=$(CROSS)-g++
  AR :=$(CROSS)-ar
else
  CC :=g++
  AR :=ar
endif
GTEST :=$(BASEDIR)/ThirdParty/gtest-1.6.0

LIB :=lib$(TARGET).a
TEST :=test_$(TARGET)
_objects :=$(patsubst %, %.o, $(TARGET) $(LIBSRC))
CFLAGS :=-g $(patsubst %, -I$(BASEDIR)/%, $(NEEDLIBS)) $(APP_CFLAGS)\
	-I${GTEST}/include
LDFLAGS := -L. -l$(TARGET)\
	$(foreach module, $(NEEDLIBS), -L$(BASEDIR)/$(module) -l$(module))\
	-L$(GTEST)/lib/.libs -lgtest -lpthread $(APP_LDFLAGS)

.PHONY: clean
all: $(TEST)
$(TEST): $(TEST).c $(LIB) $(NEEDLIBS)
	$(CC) $(CFLAGS) -o $@ $(TEST).c $(LIB) $(LDFLAGS)
$(LIB): $(_objects)
	$(AR) -rs $@ $^
%.s: %.c
	$(CC) -S $(CFLAGS) $^ $(LDFLAGS)
clean.%:
	make -C $(BASEDIR)/$(patsubst clean.%,%, $@) clean
clean: $(foreach module, $(NEEDLIBS), clean.$(module))
	-rm -f $(TEST) $(LIB) $(_objects) *~
$(NEEDLIBS):
	make -C $(BASEDIR)/$@

# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed
