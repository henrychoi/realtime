TARGET = jitter
# Only support C file for now. Example: bug hello
DEPENDENCY=timespec
CCFLAGS=-Wno-pointer-to-int-cast
LDFLAGS=-lpthread -lrt
_HEADERS = $(patsubst %, %.h, $(DEPENDENCY))
_SOURCES = $(patsubst %, %.c, $(TARGET) $(DEPENDENCY))
_OBJECTS = $(patsubst %, %.o, $(TARGET) $(DEPENDENCY))

# Rules ##################################
all: $(TARGET)
$(TARGET): $(_OBJECTS)
	 gcc -o $@ $^ $(LDFLAGS)
debug: $(_OBJECTS)
	 @echo "ld -o $@ $^ $(LDFLAGS)"
%.o: %.c
	gcc -c $(CCFLAGS) $< -o $@
.PHONY: clean
clean:
	rm -f $(TARGET) $(_OBJECTS)

# Appendix ###########################################
# $@ means the target of the rule
# $? All prerequisites NEWER than the target, w/ space inbetween
# $< First prerequisite
# $^ All prerequisites, with duplicates removed

# If you don't mind compiling all sources each time, this is a much
# simpler rule
#$(TARGET): $(_SOURCES) $(_HEADERS)
#	gcc $(CCFLAGS) $(_SOURCES) -o $@ $(LDFLAGS)
