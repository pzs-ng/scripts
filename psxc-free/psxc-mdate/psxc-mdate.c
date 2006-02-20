#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <time.h>
#include <stdlib.h>

int main( int argc, char *argv[] ){
	struct stat filestats;
	if (argc < 2)
		return 1;
	if (stat(argv[1], &filestats) == -1)
		return 1;
	if (argc > 2)
		printf("%lld\n", (long long)(time(0) - atoi(argv[2]) * 60 * 60 * 24));
	else
		printf( "%lld\n", (long long)filestats.st_mtime);
	return 0;
}

