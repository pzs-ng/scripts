/****************************************
 * psxc-symdate v0.2
 * =================
 * small script to replace the date on symlinks to the date of
 * the destination. Ie, symlink and what it points to will get
 * the same creation-date.
 * Currently only works on FreeBSD (not tested on any of the 
 * other *BSD's yet.
 * DOES (PROBABLY) NOT WORK on (most) Linux (yet).
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>
#include <utime.h>
#include <sys/syscall.h>
#include <errno.h>
#include <string.h>

int
main(int argc, char* argv[])
{
	struct stat buf[2];
	struct timeval times[2];
	int ret = 0;

	if (argc < 2) {
		fprintf(stderr, "usage: %s file ...\n", argv[0]);
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
	if (ret = lutimes(argv[1], times))
		printf("%s error: Failed to change date on symlink : %s\n", argv[0], strerror(errno));
#else
	printf("%s error: Sorry - doesn't look like your system is able to change date on symlinks\n", argv[0]);
	ret = 1;
#endif
	return ret;
}

