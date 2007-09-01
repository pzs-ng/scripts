/****************************************
 * psxc-symdate v0.3
 * =================
 * small script to replace the date on symlinks to the date of
 * the destination. Ie, symlink and what it points to will get
 * the same creation-date.
 * Currently only works on FreeBSD (not tested on any of the 
 * other *BSD's yet) and Linux with kernel 2.6.22 (or higher)
 * (thanks to rasta for the linux compat patch).
 *
 * compile with:
 * gcc -W -Wall -g -O2 -static psxc-symdate psxc-symdate.c
 * then move the bin to wherever you want it.
 *
 * Usage: psxc-symdate <path/to/symlink>
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <utime.h>
#include <sys/syscall.h>
#include <errno.h>
#include <string.h>
#ifndef SYS_lutimes
 #define __USE_ATFILE
 #include <fcntl.h>
#endif

int
main(int argc, char* argv[])
{
	struct stat buf[2];
	struct timeval times[2];
	bzero(times, sizeof(struct timeval) * 2);
	bzero(buf, sizeof(struct stat) * 2);
	int ret = 0;

	if (argc < 2) {
		fprintf(stderr, "usage: %s <symlink>\n", argv[0]);
		return(1);
	}

	lstat(argv[1], &buf[0]);
	if (!S_ISLNK(buf[0].st_mode)) {
		printf("%s error: %s is not a symlink.\n", argv[0], argv[1]);
		return 1;
	}
	stat(argv[1], &buf[0]);
#ifndef st_birthtime
	times[0].tv_sec = times[1].tv_sec = buf[0].st_mtime;
#else
	times[0].tv_sec = times[1].tv_sec = buf[0].st_birthtime;
#endif
#ifdef SYS_lutimes
	if ((ret = lutimes(argv[1], times)))
		printf("%s error (%d): Failed to change date on %s : %s\n", argv[0], errno, argv[1], strerror(errno));
#elif defined(__NR_utimensat)
	if ((ret = (syscall(__NR_utimensat, AT_FDCWD, argv[1], times, AT_SYMLINK_NOFOLLOW))))
		printf("%s error (%d): utimensat on %s failed : %s\n", argv[0], errno, argv[1], strerror(errno));
#else
	printf("%s error: Sorry - doesn't look like your system is able to change date on symlinks\n", argv[0]);
	ret = 1;
#endif
	return ret;
}

