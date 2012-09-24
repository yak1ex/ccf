CFLAGS=-DSECCOMP_BPF_STANDALONE -Wall -Werror -Wextra -Wno-missing-field-initializers -I../../chromium
CXXFLAGS=-std=gnu++0x -DSECCOMP_BPF_STANDALONE -Wall -Werror -Wextra -Wno-missing-field-initializers -I../../chromium
LDFLAGS=-lrt

CHROMIUM_DIR=../../chromium/sandbox/linux/seccomp-bpf

all: libsandbox.a sandbox-compiler

limit: test_.o libsandbox.a
	$(CXX) -o $@ $^ ${LDFLAGS}

test_.o: test.o
	objcopy --redefine-sym main=main_ test.o test_.o

sandbox-compiler: sandbox-compiler.o libseccomp_bpf_sa.a
	$(CXX) -o $@ $^ ${LDFLAGS}

sandbox-compiier.o: limit.cc
	$(CXX) $(CXXFLAGS) -DSANDBOX_COMPILER -c -o $@ $<

libsandbox.a: sandbox_bpf.o util.o verifier.o limit.o syscall-names.o
	$(AR) r $@ $+

libseccomp_bpf_sa.a: sandbox_bpf.o util.o verifier.o
	$(AR) r $@ $+

sandbox_bpf.o: $(CHROMIUM_DIR)/sandbox_bpf.cc
	$(CXX) $(CXXFLAGS) -c -o $@ $<

util.o: $(CHROMIUM_DIR)/util.cc
	$(CXX) $(CXXFLAGS) -c -o $@ $<

verifier.o: $(CHROMIUM_DIR)/verifier.cc
	$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	-rm -f *.o *.a syscall-names.c limit

include syscall-reporter.mk
