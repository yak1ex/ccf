CFLAGS=-DSECCOMP_BPF_STANDALONE -Wall -Werror -Wextra -Wno-missing-field-initializers -I../../chromium
CXXFLAGS=-std=gnu++0x -DSECCOMP_BPF_STANDALONE -Wall -Werror -Wextra -Wno-missing-field-initializers -I../../chromium
LDFLAGS=

CHROMIUM_DIR=../../chromium/sandbox/linu/seccomp-bpf

limit: libseccomp_bpf_sa.a
limit: limit.o test_.o syscall-names.o
	$(CXX) -o $@ $^ ${LDFLAGS}

test_.o: test.o
	objcopy --redefine-sym main=main_ test.o test_.o

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
