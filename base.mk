THIRDPARTY=../../ThirdParty
CUNIT=$(THIRDPARTY)/CUnit-2.1-2/CUnit

LIB=lib$(TARGET).a
TEST=test_$(TARGET)
_OBJECTS=$(patsubst %, %.o, $(TARGET) $(LIBSRC))

all: $(TEST)
$(LIB): $(_OBJECTS)
	ar -rs $@ $^
%.o: %.c
	gcc -c -g $< -o $@
clean:
	rm -f $(TEST) $(LIB) $(_OBJECTS)
.PHONY: clean

# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed
