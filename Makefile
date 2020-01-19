# Copyright (c) 2020 Calvin Rose
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.

################################
##### Set global variables #####
################################

PREFIX?=/usr/local

INCLUDEDIR?=$(PREFIX)/include
BINDIR?=$(PREFIX)/bin
LIBDIR?=$(PREFIX)/lib
JANET_BUILD?="\"$(shell git log --pretty=format:'%h' -n 1 || 'local')\""
CLIBS=-lm -lpthread
JANET_TARGET=build/janet
JANET_LIBRARY=build/libjanet.so
JANET_STATIC_LIBRARY=build/libjanet.a
JANET_PATH?=$(LIBDIR)/janet
MANPATH?=$(PREFIX)/share/man/man1/
PKG_CONFIG_PATH?=$(LIBDIR)/pkgconfig
DEBUGGER=gdb

CFLAGS:=$(CFLAGS) -std=c99 -Wall -Wextra -Isrc/include -Isrc/conf -fPIC -O2 -fvisibility=hidden \
	   -DJANET_BUILD=$(JANET_BUILD)
LDFLAGS=-rdynamic

# For installation
LDCONFIG:=ldconfig "$(LIBDIR)"

# Check OS
UNAME:=$(shell uname -s)
ifeq ($(UNAME), Darwin)
	CLIBS:=$(CLIBS) -ldl
	LDCONFIG:=
else ifeq ($(UNAME), Linux)
	CLIBS:=$(CLIBS) -lrt -ldl
endif
# For other unix likes, add flags here!
ifeq ($(UNAME), Haiku)
	LDCONFIG:=
	LDFLAGS=-Wl,--export-dynamic
endif

$(shell mkdir -p build/core build/mainclient build/webclient build/boot)
all: $(JANET_TARGET) $(JANET_LIBRARY) $(JANET_STATIC_LIBRARY)

######################
##### Name Files #####
######################

JANET_HEADERS=src/include/janet.h src/conf/janetconf.h

JANET_LOCAL_HEADERS=src/core/features.h \
					src/core/util.h \
					src/core/state.h \
					src/core/gc.h \
					src/core/vector.h \
					src/core/fiber.h \
					src/core/regalloc.h \
					src/core/compile.h \
					src/core/emit.h \
					src/core/symcache.h

JANET_CORE_SOURCES=src/core/abstract.c \
				   src/core/array.c \
				   src/core/asm.c \
				   src/core/buffer.c \
				   src/core/bytecode.c \
				   src/core/capi.c \
				   src/core/cfuns.c \
				   src/core/compile.c \
				   src/core/corelib.c \
				   src/core/debug.c \
				   src/core/emit.c \
				   src/core/fiber.c \
				   src/core/gc.c \
				   src/core/inttypes.c \
				   src/core/io.c \
				   src/core/marsh.c \
				   src/core/math.c \
				   src/core/os.c \
				   src/core/parse.c \
				   src/core/peg.c \
				   src/core/pp.c \
				   src/core/regalloc.c \
				   src/core/run.c \
				   src/core/specials.c \
				   src/core/string.c \
				   src/core/strtod.c \
				   src/core/struct.c \
				   src/core/symcache.c \
				   src/core/table.c \
				   src/core/thread.c \
				   src/core/tuple.c \
				   src/core/typedarray.c \
				   src/core/util.c \
				   src/core/value.c \
				   src/core/vector.c \
				   src/core/vm.c \
				   src/core/wrap.c

JANET_BOOT_SOURCES=src/boot/array_test.c \
				   src/boot/boot.c \
				   src/boot/buffer_test.c \
				   src/boot/number_test.c \
				   src/boot/system_test.c \
				   src/boot/table_test.c
JANET_BOOT_HEADERS=src/boot/tests.h

JANET_MAINCLIENT_SOURCES=src/mainclient/line.c src/mainclient/main.c
JANET_MAINCLIENT_HEADERS=src/mainclient/line.h

JANET_WEBCLIENT_SOURCES=src/webclient/main.c

##################################################################
##### The bootstrap interpreter that compiles the core image #####
##################################################################

JANET_BOOT_OBJECTS=$(patsubst src/%.c,build/%.boot.o,$(JANET_CORE_SOURCES) $(JANET_BOOT_SOURCES)) \
	build/boot.gen.o

$(JANET_BOOT_OBJECTS): $(JANET_BOOT_HEADERS)

build/%.boot.o: src/%.c $(JANET_HEADERS) $(JANET_LOCAL_HEADERS)
	$(CC) $(CFLAGS) -DJANET_BOOTSTRAP -o $@ -c $<

build/janet_boot: $(JANET_BOOT_OBJECTS)
	$(CC) $(CFLAGS) -DJANET_BOOTSTRAP -o $@ $^ $(CLIBS)

# Now the reason we bootstrap in the first place
build/core_image.c: build/janet_boot
	build/janet_boot $@ JANET_PATH '$(JANET_PATH)' JANET_HEADERPATH '$(INCLUDEDIR)/janet'

##########################################################
##### The main interpreter program and shared object #####
##########################################################

JANET_CORE_OBJECTS=$(patsubst src/%.c,build/%.o,$(JANET_CORE_SOURCES)) build/core_image.o
JANET_MAINCLIENT_OBJECTS=$(patsubst src/%.c,build/%.o,$(JANET_MAINCLIENT_SOURCES))

$(JANET_MAINCLIENT_OBJECTS): $(JANET_MAINCLIENT_HEADERS)

# Compile the core image generated by the bootstrap build
build/core_image.o: build/core_image.c $(JANET_HEADERS) $(JANET_LOCAL_HEADERS)
	$(CC) $(CFLAGS) -o $@ -c $<

build/%.o: src/%.c $(JANET_HEADERS) $(JANET_LOCAL_HEADERS)
	$(CC) $(CFLAGS) -o $@ -c $<

$(JANET_TARGET): $(JANET_CORE_OBJECTS) $(JANET_MAINCLIENT_OBJECTS)
	$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $^ $(CLIBS)

$(JANET_LIBRARY): $(JANET_CORE_OBJECTS)
	$(CC) $(LDFLAGS) $(CFLAGS) -shared -o $@ $^ $(CLIBS)

$(JANET_STATIC_LIBRARY): $(JANET_CORE_OBJECTS)
	$(AR) rcs $@ $^

#############################
##### Generated C files #####
#############################

%.gen.o: %.gen.c
	$(CC) $(CFLAGS) -o $@ -c $<

build/xxd: tools/xxd.c
	$(CC) $< -o $@

build/webinit.gen.c: src/webclient/webinit.janet build/xxd
	build/xxd $< $@ janet_gen_webinit
build/boot.gen.c: src/boot/boot.janet build/xxd
	build/xxd $< $@ janet_gen_boot

########################
##### Amalgamation #####
########################

amalg: build/shell.c build/janet.c build/janet.h build/core_image.c build/janetconf.h

AMALG_SOURCE=$(JANET_LOCAL_HEADERS) $(JANET_CORE_SOURCES) build/core_image.c
build/janet.c: $(AMALG_SOURCE) tools/amalg.janet $(JANET_TARGET)
	$(JANET_TARGET) tools/amalg.janet $(AMALG_SOURCE) > $@

AMALG_SHELL_SOURCE=src/mainclient/line.h src/mainclient/line.c src/mainclient/main.c
build/shell.c: $(JANET_TARGET) tools/amalg.janet $(AMALG_SHELL_SOURCE)
	$(JANET_TARGET) tools/amalg.janet $(AMALG_SHELL_SOURCE) > $@

build/janet.h: src/include/janet.h
	cp $< $@

build/janetconf.h: src/conf/janetconf.h
	cp $< $@

###################
##### Testing #####
###################

TEST_SCRIPTS=$(wildcard test/suite*.janet)

repl: $(JANET_TARGET)
	./$(JANET_TARGET)

debug: $(JANET_TARGET)
	$(DEBUGGER) ./$(JANET_TARGET)

VALGRIND_COMMAND=valgrind --leak-check=full

valgrind: $(JANET_TARGET)
	$(VALGRIND_COMMAND) ./$(JANET_TARGET)

test: $(JANET_TARGET) $(TEST_PROGRAMS)
	for f in test/suite*.janet; do ./$(JANET_TARGET) "$$f" || exit; done
	for f in examples/*.janet; do ./$(JANET_TARGET) -k "$$f"; done
	./$(JANET_TARGET) -k auxbin/jpm

valtest: $(JANET_TARGET) $(TEST_PROGRAMS)
	for f in test/suite*.janet; do $(VALGRIND_COMMAND) ./$(JANET_TARGET) "$$f" || exit; done
	for f in examples/*.janet; do ./$(JANET_TARGET) -k "$$f"; done
	$(VALGRIND_COMMAND) ./$(JANET_TARGET) -k auxbin/jpm

callgrind: $(JANET_TARGET)
	for f in test/suite*.janet; do valgrind --tool=callgrind ./$(JANET_TARGET) "$$f" || exit; done

########################
##### Distribution #####
########################

dist: build/janet-dist.tar.gz

build/janet-%.tar.gz: $(JANET_TARGET) \
	src/include/janet.h src/conf/janetconf.h \
	jpm.1 janet.1 LICENSE CONTRIBUTING.md $(JANET_LIBRARY) $(JANET_STATIC_LIBRARY) \
	build/doc.html README.md build/janet.c build/shell.c auxbin/jpm
	$(eval JANET_DIST_DIR = "janet-$(shell basename $*)")
	mkdir -p build/$(JANET_DIST_DIR)
	cp -r $^ build/$(JANET_DIST_DIR)/
	cd build && tar -czvf ../$@ $(JANET_DIST_DIR)

#########################
##### Documentation #####
#########################

docs: build/doc.html

build/doc.html: $(JANET_TARGET) tools/gendoc.janet
	$(JANET_TARGET) tools/gendoc.janet > build/doc.html

########################
##### Installation #####
########################

SONAME=libjanet.so.1

.PHONY: build/janet.pc
build/janet.pc: $(JANET_TARGET)
	echo 'prefix=$(PREFIX)' > $@
	echo 'exec_prefix=$${prefix}' >> $@
	echo 'includedir=$(INCLUDEDIR)/janet' >> $@
	echo 'libdir=$(LIBDIR)' >> $@
	echo "" >> $@
	echo "Name: janet" >> $@
	echo "Url: https://janet-lang.org" >> $@
	echo "Description: Library for the Janet programming language." >> $@
	$(JANET_TARGET) -e '(print "Version: " janet/version)' >> $@
	echo 'Cflags: -I$${includedir}' >> $@
	echo 'Libs: -L$${libdir} -ljanet $(LDFLAGS)' >> $@
	echo 'Libs.private: $(CLIBS)' >> $@

install: $(JANET_TARGET) build/janet.pc
	mkdir -p '$(BINDIR)'
	cp $(JANET_TARGET) '$(BINDIR)/janet'
	mkdir -p '$(INCLUDEDIR)/janet'
	cp -rf $(JANET_HEADERS) '$(INCLUDEDIR)/janet'
	mkdir -p '$(JANET_PATH)'
	mkdir -p '$(LIBDIR)'
	cp $(JANET_LIBRARY) '$(LIBDIR)/libjanet.so.$(shell $(JANET_TARGET) -e '(print janet/version)')'
	cp $(JANET_STATIC_LIBRARY) '$(LIBDIR)/libjanet.a'
	ln -sf $(SONAME) '$(LIBDIR)/libjanet.so'
	ln -sf libjanet.so.$(shell $(JANET_TARGET) -e '(print janet/version)') $(LIBDIR)/$(SONAME)
	cp -rf auxbin/* '$(BINDIR)'
	mkdir -p '$(MANPATH)'
	cp janet.1 '$(MANPATH)'
	cp jpm.1 '$(MANPATH)'
	mkdir -p '$(PKG_CONFIG_PATH)'
	cp build/janet.pc '$(PKG_CONFIG_PATH)/janet.pc'
	-$(LDCONFIG)

uninstall:
	-rm '$(BINDIR)/janet'
	-rm '$(BINDIR)/jpm'
	-rm -rf '$(INCLUDEDIR)/janet'
	-rm -rf '$(LIBDIR)'/libjanet.*
	-rm '$(PKG_CONFIG_PATH)/janet.pc'
	-rm '$(MANPATH)/janet.1'
	-rm '$(MANPATH)/jpm.1'
	# -rm -rf '$(JANET_PATH)'/* - err on the side of correctness here

#################
##### Other #####
#################

format:
	tools/format.sh

grammar: build/janet.tmLanguage
build/janet.tmLanguage: tools/tm_lang_gen.janet $(JANET_TARGET)
	$(JANET_TARGET) $< > $@

clean:
	-rm -rf build vgcore.* callgrind.*

test-install:
	cd test/install \
		&& rm -rf build .cache .manifests \
		&& jpm --verbose build \
		&& jpm --verbose test \
		&& build/testexec \
		&& jpm --verbose quickbin testexec.janet build/testexec2 \
		&& build/testexec2 \
		&& jpm --verbose --testdeps --modpath=. install https://github.com/janet-lang/json.git
	cd test/install && jpm --verbose --test --modpath=. install https://github.com/janet-lang/jhydro.git
	cd test/install && jpm --verbose --test --modpath=. install https://github.com/janet-lang/path.git
	cd test/install && jpm --verbose --test --modpath=. install https://github.com/janet-lang/argparse.git

build/embed_janet.o: build/janet.c $(JANET_HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@
build/embed_main.o: test/amalg/main.c $(JANET_HEADERS)
	$(CC) $(CFLAGS) -c $< -o $@
build/embed_test: build/embed_janet.o build/embed_main.o
	$(CC) $(LDFLAGS) $(CFLAGS) -o $@ $^ $(CLIBS)

test-amalg: build/embed_test
	./build/embed_test

.PHONY: clean install repl debug valgrind test amalg \
	valtest emscripten dist uninstall docs grammar format
