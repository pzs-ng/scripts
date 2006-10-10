/* 
 * psxc-nukewipe v0.1
 * ==================
 * Small script/binary to help remove nuked releases. May be used as a channel
 * command (!nukewipe) or as a crontabbed script.
 * The script takes two args - number of hours the nuke must be before removing
 * it, and an optional path arg, to only remove nukes according to path.
 *
 * To compile, do:
 *   gcc -g -W -O2 -Wall -static -o /glftpd/bin/psxc-nukewipe psxc-nukewipe.c
 * (on 64bit processors you need to add -m32 - the bin must be compiled 32bit)
 *
 * If the bin is to be run by bot or crontabbed as non-root, the bin needs +s:
 *   chmod +s /glftpd/bin/psxc-nukewipe
 *
 * Don't forget to edit the options below - there's no external config file.
 *
 */


/* Enter here the prefix of the nuked dirs - see nuke_dir_style in glftpd.docs.
 */
#define NUKESTRING	"NUKED-"

/* The prefix in glftpd.log - should match your bot.
 */
#define PREFIX		"NWIPE"

/* Where you have installed glftpd - see rootpath in glftpd.docs.
 */
#define GLROOT		"/glftpd"

/* The location of the binary nukelog glftpd uses. Path is chroot'ed.
 */
#define NUKELOG		"/ftp-data/logs/nukelog"

/* The location of glftpd.log.
 */
#define GLLOG		"/ftp-data/logs/glftpd.log"

/* What to do with nuked dirs found. Add 'echo' in front to turn on testmode.
 */
#define RMCOMMAND	"echo rm -fR"

/*
 * END OF CONFIG
 ***************************************************************
 ***************************************************************
 */

#include <time.h>
#include <sys/param.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <fnmatch.h>

struct nukelog {
        ushort status;          /* 0 = NUKED, 1 = UNNUKED */
        time_t nuketime;        /* The nuke time since epoch (man 2 time) */
        char nuker[12];         /* The name of the nuker */
        char unnuker[12];       /* The name of the unnuker */
        char nukee[12];         /* The name of the nukee */
        ushort mult;            /* The nuke multiplier */
        float bytes;            /* The number of bytes nuked */
        char reason[60];        /* The nuke reason */
        char dirname[255];      /* The dirname (fullpath) */
        struct nukelog *nxt;    /* Unused, kept for compatibility reasons */
        struct nukelog *prv;    /* Unused, kept for compatibility reasons */
};

int get_dirage(time_t dirtime) {
	unsigned int hours = 0;
	time_t timenow = time(NULL);
	time_t difftime = timenow - dirtime;
        while(difftime >= (time_t)3600) {
		difftime -= (time_t)3600;
		hours++;
	}
	return hours;
}

int main(int argc, char *argv[]) {
FILE *file, *file2;
uid_t oldid = geteuid();
char temp[MAXPATHLEN];
char temp2[MAXPATHLEN];
char nukelog[MAXPATHLEN];
char gllog[MAXPATHLEN];
char nukeddir[MAXPATHLEN];
char mindir[MAXPATHLEN];
struct nukelog nukeentry;
struct stat st;
unsigned int minhours, cnt1, cnt2;
char *p = NULL, *q = NULL;
time_t timenow;

if (argc == 1 || !strcmp(argv[1],"--help") || strlen(argv[1]) == 0) {
	printf("\nUsage:   %s <hours> [path]\n",argv[0]);
	printf("         hours : nuked dirs older than <hours> hours will be wiped.\n");
	printf("         path  : (minimum) path to match (optional).\n");
	printf("Example: %s 72 /site/incoming/0DAY  <- will remove nukes in 0day older than 3 days.\n", argv[0]);
	printf("Example: %s 72 */0DAY/*             <- will remove nukes in 0day older than 3 days.\n\n", argv[0]);
	return 0;
	}
minhours = atoi(argv[1]);
if (argc > 2)
	strncpy(mindir, argv[2], sizeof(mindir));
else
	sprintf(mindir, "/");

seteuid(0);
snprintf(nukelog, sizeof(nukelog), "/%s/%s", GLROOT, NUKELOG);
if ((file = fopen(nukelog, "rb")) == NULL) {
	printf("Unable to open (read) %s: %s\n",nukelog, strerror(errno));
	return 1;
}
snprintf(gllog, sizeof(gllog), "/%s/%s", GLROOT, GLLOG);
if ((file2 = fopen(gllog, "ab")) == NULL) {
	printf("Unable to open (append) %s: %s\n",gllog, strerror(errno));
	fclose(file);
	return 1;
}
fclose(file2);
while(!feof(file)) {
	if (fread(&nukeentry, sizeof(struct nukelog), 1, file) < 1)
		break;
	if ((unsigned int)get_dirage(nukeentry.nuketime) >= minhours && !nukeentry.status) {
		snprintf(temp, sizeof(temp), "%s", nukeentry.dirname);
		p = temp;
		cnt1 = 0;		
		cnt2 = 0;
		while (1) {
			while (p[cnt1] != '/' && p[cnt1] != '\0')
				cnt1++;
			if (p[cnt1] == '/') {
				cnt2 = cnt1;
				cnt1++;
			} else
				break;
		}
		p[cnt2] = '\0';
		q = p + cnt2 + 1;
		snprintf(nukeddir, sizeof(nukeddir), "/%s/%s/%s%s", GLROOT, p, NUKESTRING, q);
		snprintf(temp2, sizeof(temp2), "%s/%s%s", p, NUKESTRING, q);
		if (stat(nukeddir, &st) == 0 && (!fnmatch(mindir, temp2, FNM_PATHNAME|FNM_LEADING_DIR) || !fnmatch(mindir, temp2, 0))) {
			if ((file2 = fopen(gllog, "ab")) != NULL) {
				timenow = time(NULL);
				fprintf(file2, "%.24s \"%s: \"%s/%s%s\" \"%s\" \"%.2f\"\n", ctime(&timenow), PREFIX, p, NUKESTRING, q, q, nukeentry.bytes);
			} else {
				printf("Unable to open (append) %s: %s\n",gllog, strerror(errno));
				fclose(file);
				return 1;
			}
			fclose(file2);
			snprintf(temp2, sizeof(temp2), "%s %s", RMCOMMAND, nukeddir);
			if (system(temp2) == -1)
				printf("Error: failed to execute %s : %s\n", temp2, strerror(errno));
		}

	}
}
fclose(file);
setuid(oldid);
return 0;
}

