#include <iostream>

#include <unistd.h>
#include <stdlib.h>
#include <signal.h>
#include <sys/time.h>
#include <sys/resource.h>

#include "sandbox/linux/seccomp-bpf/sandbox_bpf.h"

#define UNUSED(var) do { if(var){} } while(0)

using playground2::Sandbox;

#define ERR EPERM

// POSIX doesn't define any async-signal safe function for converting
// an integer to ASCII. We'll have to define our own version.
// itoa_r() converts a (signed) integer to ASCII. It returns "buf", if the
// conversion was successful or NULL otherwise. It never writes more than "sz"
// bytes. Output will be truncated as needed, and a NUL character is always
// appended.
static char *itoa_r(int i, char *buf, size_t sz) {
  // Make sure we can write at least one NUL byte.
  size_t n = 1;
  if (n > sz) {
    return NULL;
  }

  // Handle negative numbers.
  char *start = buf;
  int minint = 0;
  if (i < 0) {
    // Make sure we can write the '-' character.
    if (++n > sz) {
      *start = '\000';
      return NULL;
    }
    *start++ = '-';

    // Turn our number positive.
    if (i == -i) {
      // The lowest-most negative integer needs special treatment.
      minint = 1;
      i = -(i + 1);
    } else {
      // "Normal" negative numbers are easy.
      i = -i;
    }
  }

  // Loop until we have converted the entire number. Output at least one
  // character (i.e. '0').
  char *ptr = start;
  do {
    // Make sure there is still enough space left in our output buffer.
    if (++n > sz) {
      buf = NULL;
      goto truncate;
    }

    // Output the next digit and (if necessary) compensate for the lowest-most
    // negative integer needing special treatment. This works because, no
    // matter the bit width of the integer, the lowest-most integer always ends
    // in 2, 4, 6, or 8.
    *ptr++ = i%10 + '0' + minint;
    minint = 0;
    i /= 10;
  } while (i);
 truncate:  // Terminate the output with a NUL character.
  *ptr = '\000';

  // Conversion to ASCII actually resulted in the digits being in reverse
  // order. We can't easily generate them in forward order, as we can't tell
  // the number of characters needed until we are done converting.
  // So, now, we reverse the string (except for the possible "-" sign).
  while (--ptr > start) {
    char ch = *ptr;
    *ptr = *start;
    *start++ = ch;
  }
  return buf;
}

extern const char* syscall_names[];

// This handler gets called, whenever we encounter a system call that we
// don't recognize explicitly. For the purposes of this program, we just
// log the system call and then deny it. More elaborate sandbox policies
// might try to evaluate the system call in user-space, instead.
// The only notable complication is that this function must be async-signal
// safe. This restricts the libary functions that we can call.
static intptr_t defaultHandler(const struct arch_seccomp_data& data,
                               void *) {
  static const char msg0[] = "Disallowed system call #";
  static const char msg1[] = "\n";
  char buf[sizeof(msg0) - 1 + 25 + sizeof(msg1) + 30]; // append name

  *buf = '\000';
  strncat(buf, msg0, sizeof(buf));

  char *ptr = strrchr(buf, '\000');
  itoa_r(data.nr, ptr, sizeof(buf) - (ptr - buf));

  ptr = strrchr(ptr, '\000');
  strncat(ptr, " ", sizeof(buf) - (ptr - buf));

  ptr = strrchr(ptr, '\000');
  strncat(ptr, syscall_names[data.nr], sizeof(buf) - (ptr - buf));

  ptr = strrchr(ptr, '\000');
  strncat(ptr, msg1, sizeof(buf) - (ptr - buf));

  ptr = strrchr(ptr, '\000');
  if (HANDLE_EINTR(write(2, buf, ptr - buf))) { }

  return -ERR;
}

static Sandbox::ErrorCode evaluator(int sysno) {
	switch(sysno) {
	case __NR_brk:
	case __NR_close:
	case __NR_exit: case __NR_exit_group:
	case __NR_fstat64:
	case __NR_fstat:
	case __NR_gettimeofday:
	case __NR_nanosleep:
	case __NR_time:
	case __NR_read: case __NR_readv:
	case __NR_write: case __NR_writev:
	case __NR_mmap:
	case __NR_mmap2:
		return Sandbox::SB_ALLOWED;
	default:
		return Sandbox::ErrorCode(defaultHandler, NULL);
	}
}

void xcpu(int sig)
{
	UNUSED(sig);
	write(0, "\n===xcpu===\n", 12);
	exit(2);
}

extern "C" int main_(int argc, char **argv);

int main(int argc, char** argv)
{
	UNUSED(argc);
	UNUSED(argv);

	struct sigaction sa;
	sa.sa_handler = xcpu;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sigaction(SIGXCPU, &sa, NULL);

	struct rlimit rl;
	rl.rlim_max = rl.rlim_cur = 4 * 1024 * 1024;
	setrlimit(RLIMIT_AS, &rl);
	getrlimit(RLIMIT_AS, &rl);
	std::cout << "RLIMIT_AS: hard: " << rl.rlim_max << " soft: " << rl.rlim_cur << std::endl;
	rl.rlim_max = 2; rl.rlim_cur = 1;
	setrlimit(RLIMIT_CPU, &rl);
	getrlimit(RLIMIT_CPU, &rl);
	std::cout << "RLIMIT_CPU: hard: " << rl.rlim_max << " soft: " << rl.rlim_cur << std::endl;

	int proc_fd = open("/proc", O_RDONLY|O_DIRECTORY);
	if(Sandbox::supportsSeccompSandbox(proc_fd) != Sandbox::STATUS_AVAILABLE) {
		perror("sandbox");
		exit(1);
	}
	Sandbox::setProcFd(proc_fd);
	Sandbox::setSandboxPolicy(evaluator, NULL);
	Sandbox::startSandbox();

	return main_(argc, argv);
}
