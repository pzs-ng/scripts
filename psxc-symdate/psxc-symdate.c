/****************************************
 * psxc-symdate v0.1
 * =================
 * small script to replace the date on symlinks to the date of
 * the destination. Ie, symlink and what it points to will get
 * the same creation-date.
 * Currently only works on FreeBSD (not tested on any of the 
 * other *BSD's yet.
 * DOES NOT WORK on Linux (yet).
 */

#include <stdio.h>
#include <sys/types.h>
#include <sys/time.h>
#include <sys/stat.h>

int
main(int argc, char* argv[])
{
	struct stat buf[2];
	struct timeval times[2];

	if (argc < 2) {
		fprintf(stderr, "usage: %s file ...\n", argv[0]);
		return(1);
	}

	stat(argv[1], &buf[0]);
	times[0].tv_sec = times[1].tv_sec = buf[0].st_birthtime;
	lutimes(argv[1], times);
}

