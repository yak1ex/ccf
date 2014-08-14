#
# syscall reporting example for seccomp
#
# Copyright (c) 2012 The Chromium OS Authors <chromium-os-dev@chromium.org>
# Authors:
#  Kees Cook <keescook@chromium.org>
#
# The code may be used by anyone for any purpose, and can serve as a
# starting point for developing applications using mode 2 seccomp.

#syscall-names.h: /usr/include/sys/syscall.h syscall-reporter.mk
# - remove static specifier
# - add guard for madvise1 to avoid override
syscall-names.c: /usr/include/i386-linux-gnu/sys/syscall.h syscall-reporter.mk
	echo "const char *syscall_names[] = {" > $@ ;\
	echo "#include <sys/syscall.h>" | cpp -dM | grep '^#define __NR_' | \
		LC_ALL=C sed -e '/madvise1/d' | \
		LC_ALL=C sed -r -n -e 's/^\#define[ \t]+__NR_([a-z0-9_]+)[ \t]+([0-9]+)(.*)/ [\2] = "\1",/p' >> $@ ;\
	echo "};" >> $@

#syscall-reporter.o: syscall-reporter.c syscall-names.h
