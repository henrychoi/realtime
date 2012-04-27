TARGET=timespec
LIBSRC=
include ../base.mk ##################################

$(TEST): $(TEST).c $(LIB)
	gcc -g -static -I$(CUNIT)/Headers -o $@ $^ \
	-Wno-pointer-to-int-cast \
	-L$(CUNIT)/Sources/.libs -lcunit -L. -l$(TARGET)
debug: $(TEST).c #$(TARGET).c
	gcc -S -g $^ \
	-mtune=core2 -Wno-pointer-to-int-cast \
	-I$(CUNIT)/Headers -I../timespec
