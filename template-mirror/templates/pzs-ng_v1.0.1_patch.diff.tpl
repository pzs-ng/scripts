# A simple patch for pzs-ng v1.0 (r1811)
# Will fix some issues regarding ss5 output, broken announces
# on races with >9 racers and a few other minor issues found.
# There is also a somewhat untested fix of filelocking - since
# the lock mechanism is totally rewritten in the upcoming v1.1,
# little time has been spent on fixing this.
# Also included is a fix for postdel on amd64, a small fix in the
# diz-reader, and some botstuff.
# Finally, the ability to rescan and sort mp3s has been added.
#
# How to apply:
# cd to the main dir of pzs-ng sources
# patch -p0 </path/to/pzs-ng_v1.0.1_patch.diff
#
# There should be no errors.
#


Property changes on: zipscript/utils
___________________________________________________________________
Name: svn:ignore
   + Makefile


Index: zipscript/include/audiosort.h
===================================================================
--- zipscript/include/audiosort.h	(revision 0)
+++ zipscript/include/audiosort.h	(revision 2037)
@@ -0,0 +1,10 @@
+#ifndef _AUDIOSORT_H_
+#define _AUDIOSORT_H__
+
+#include "objects.h"
+
+extern void audioSortDir(char *);
+extern void audioSort(struct audio *, char *, char *);
+
+#endif
+
Index: zipscript/include/zsconfig.defaults.h
===================================================================
--- zipscript/include/zsconfig.defaults.h	(revision 1811)
+++ zipscript/include/zsconfig.defaults.h	(working copy)
@@ -477,6 +477,16 @@
 #endif
 
 /*
+ * Wether or not we delete any links
+ * with the same name when we try to make
+ * a new link. (If we don't, the old link will stay,
+ * and making a new one will fail)
+ */
+#ifndef delete_old_link
+# define delete_old_link	TRUE
+#endif
+
+/*
  * Audio related checks for quality/type - here you enable/disable the
  * restriction you defined earlier. If warn is true, any banned files will
  * not be deleted, but instead a warning message will be logged to your
@@ -695,7 +705,7 @@
 #define zipscript_sfv_ok	"| + SFV-file: oK!                                  |\n"
 #endif
 #ifndef zipscript_any_ok
-#define zipscript_any_ok	"| + File: ok!                                      |\n"
+#define zipscript_any_ok	"| + File: ok! (allowed w/o any checks)             |\n"
 #endif
 #ifndef zipscript_SFV_ok
 #define zipscript_SFV_ok	"| + CRC-Check: oK!                                 |\n"
Index: zipscript/src/audiosort.c
===================================================================
--- zipscript/src/audiosort.c	(revision 0)
+++ zipscript/src/audiosort.c	(revision 2037)
@@ -0,0 +1,102 @@
+#include <string.h>
+
+#ifndef HAVE_STRLCPY
+# include "strl/strl.h"
+#endif
+
+#include "../conf/zsconfig.h"
+#include "zsconfig.defaults.h"
+
+#include "objects.h"
+#include "zsfunctions.h"
+#include "audiosort.h"
+#include "multimedia.h"
+
+void audioSortDir(char *targetDir)
+{
+	int cnt, n = 0;
+	char link_source[PATH_MAX], link_target[PATH_MAX], *file_target;
+	struct audio info;
+	DIR *ourDir; 
+	
+
+	if (*targetDir != '/')
+	{
+		d_log("audioSort: not an absolute path. (%s)\n", targetDir);
+		return;
+	}
+
+/* Look at something like that to verify that a release is complete?
+ * (And tell user to run rescan if not)
+ * char *sfv_data = NULL; 
+ *
+ * sfv_data = ng_realloc2(sfv_data, n, 1, 1, 1);
+ * sprintf(sfv_data, storage "/%s/sfvdata", targetDir);
+ * 
+ * readsfv(sfv_data, &g.v, 0);
+ */
+	
+	for (cnt = strlen(targetDir); cnt; cnt--) {
+		if (targetDir[cnt] == '/') {
+			strlcpy(link_target, targetDir + cnt + 1, n + 1);
+			link_target[n] = 0;
+			break;
+		} else {
+			n++;
+		}
+	}
+	strlcpy(link_source, targetDir, PATH_MAX);
+	
+	chdir(targetDir);
+	ourDir = opendir(targetDir);
+	file_target = findfileext(ourDir, ".mp3");
+	closedir(ourDir);
+
+	get_mpeg_audio_info(file_target, &info);
+	
+	audioSort(&info, link_source, link_target);
+}
+
+void audioSort(struct audio *info, char *link_source, char *link_target)
+{
+#if ( audio_genre_sort == TRUE ) || (audio_artist_sort == TRUE) || (audio_year_sort == TRUE) || (audio_group_sort == TRUE)
+	char *temp_p = NULL;
+	int n = 0;
+#else
+	(void)info; (void)link_source; (void)link_target;
+#endif
+
+#if ( audio_genre_sort == TRUE )
+	d_log("audioSort:   Sorting mp3 by genre (%s)\n", info->id3_genre);
+	createlink(audio_genre_path, info->id3_genre, link_source, link_target);
+#endif
+#if ( audio_artist_sort == TRUE )
+	d_log("audioSort:   Sorting mp3 by artist\n");
+	if (*info->id3_artist) {
+		d_log("audioSort:     - artist: %s\n", info->id3_artist);
+		if (memcmp(info->id3_artist, "VA", 3)) {
+			temp_p = ng_realloc(temp_p, 2, 1, 0, NULL, 1);
+			snprintf(temp_p, 2, "%c", toupper(*info->id3_artist));
+			createlink(audio_artist_path, temp_p, link_source, link_target);
+			ng_free(temp_p);
+		} else
+			createlink(audio_artist_path, "VA", link_source, link_target);
+	}
+#endif
+#if ( audio_year_sort == TRUE )
+	d_log("audioSort:   Sorting mp3 by year (%s)\n", info->id3_year);
+	if (*info->id3_year != 0)
+		createlink(audio_year_path, info->id3_year, link_source, link_target);
+#endif
+#if ( audio_group_sort == TRUE )
+	d_log("audioSort:   Sorting mp3 by group\n");
+	temp_p = remove_pattern(link_target, "*-", RP_LONG_LEFT);
+	temp_p = remove_pattern(temp_p, "_", RP_SHORT_LEFT);
+	n = (int)strlen(temp_p);
+	if (n > 0 && n < 15) {
+		d_log("audioSort:   - Valid groupname found: %s (%i)\n", temp_p, n);
+		createlink(audio_group_path, temp_p, link_source, link_target);
+	}
+#endif
+}
+
Index: zipscript/src/audiosort-bin.c
===================================================================
--- zipscript/src/audiosort-bin.c	(revision 0)
+++ zipscript/src/audiosort-bin.c	(revision 2037)
@@ -0,0 +1,61 @@
+#include <stdlib.h>
+#include <string.h>
+#include <unistd.h>
+#include <errno.h>
+
+#include "../conf/zsconfig.h"
+#include "zsfunctions.h"
+#include "audiosort.h"
+
+int main(int argc, char *argv[])
+{
+	char targetDir[PATH_MAX];
+
+#if ( program_uid > 0 )
+	setegid(program_gid);
+	seteuid(program_uid);
+#endif
+
+	umask(0666 & 000);
+
+	if (argc > 1)
+	{
+		if (*argv[1] == '/')
+		{
+			snprintf(targetDir, PATH_MAX, "%s", argv[1]);
+			d_log("audioSort: using argv[1].\n");
+		}
+		else
+		{
+			snprintf(targetDir, PATH_MAX, "%s/%s", getenv("PWD"), argv[1]);
+			d_log("audioSort: using PWD + argv[1].\n");
+		}
+	}
+	else
+	{
+		if (getenv("PWD") != NULL)
+		{
+			snprintf(targetDir, PATH_MAX, "%s", getenv("PWD"));
+			d_log("audioSort: using PWD.\n");
+		}
+		else
+		{
+			d_log("audioSort: using getcwd().\n");
+			if (getcwd(targetDir, PATH_MAX) == NULL)
+			{
+				d_log("audioSort: could not get current working dir: %s\n", strerror(errno));
+				printf("Something bad happened when trying to decide what dir to resort.\n");
+				return 1;
+			}
+		}
+	}
+	
+	d_log("audioSort: resorting dir %s.\n", targetDir);
+
+	printf("Resorting %s. :-)\n", targetDir);
+	audioSortDir(targetDir);
+	printf("Done!\n");
+
+	return 0;
+}
+
Index: zipscript/src/Makefile.in
===================================================================
--- zipscript/src/Makefile.in	(revision 1811)
+++ zipscript/src/Makefile.in	(working copy)
@@ -12,19 +12,20 @@
 
 SUNOBJS=@SUNOBJS@
 UNIVERSAL=stats.o convert.o race-file.o helpfunctions.o zsfunctions.o mp3info.o ng-version.o abs2rel.o $(SUNOBJS) $(STRLCPY)
-ZS-OBJECTS=zipscript-c.o dizreader.o complete.o multimedia.o crc.o $(UNIVERSAL)
+ZS-OBJECTS=zipscript-c.o dizreader.o complete.o multimedia.o audiosort.o crc.o $(UNIVERSAL)
 PD-OBJECTS=postdel.o dizreader.o multimedia.o crc.o $(UNIVERSAL)
 RS-OBJECTS=racestats.o dizreader.o crc.o $(UNIVERSAL)
+AS-OBJECTS=multimedia.o audiosort.o audiosort-bin.o $(UNIVERSAL)
 CU-OBJECTS=cleanup.o
 #IL-OBJECTS=incomplete-list.o
 DC-OBJECTS=datacleaner.o
 UD-OBJECTS=ng-undupe.o $(STRLCPY)
-SC-OBJECTS=rescan.o dizreader.o complete.o crc.o multimedia.o $(UNIVERSAL)
+SC-OBJECTS=rescan.o dizreader.o complete.o crc.o multimedia.o audiosort.o $(UNIVERSAL)
 CH-OBJECTS=ng-chown.o
 #ZS-DEPEND=cleanup.o incomplete-list.o complete.o datacleaner.o postdel.o racestats.o rescan.o zipscript-c.o multimedia.o $(UNIVERSAL)
 ZS-DEPEND=cleanup.o complete.o datacleaner.o postdel.o racestats.o rescan.o zipscript-c.o multimedia.o $(UNIVERSAL)
 
-all: ng-undupe zipscript-c postdel racestats cleanup datacleaner rescan ng-chown
+all: ng-undupe zipscript-c postdel racestats cleanup datacleaner rescan ng-chown audiosort
 
 $(ZS-DEPEND): ../conf/zsconfig.h
 
@@ -54,6 +55,9 @@
 ng-chown: $(CH-OBJECTS)
 	$(CC) $(CFLAGS) -o $@ $(CH-OBJECTS) $(SUNOBJS)
 
+audiosort: $(AS-OBJECTS)
+	$(CC) $(CFLAGS) -o $@ $(AS-OBJECTS)
+
 rescan: $(SC-OBJECTS)
 	$(CC) $(CFLAGS) -o $@ $(SC-OBJECTS)
 
@@ -62,16 +66,16 @@
 	chown 0:0 $(prefix)$(storage)
 	chmod 4777 $(prefix)$(storage)
 	if [ -e $(prefix)$(datapath)/logs/glftpd.log ]; then chmod 666 $(prefix)$(datapath)/logs/glftpd.log; fi
-	if [ -e $(bindir) ]; then cp -f zipscript-c postdel racestats cleanup datacleaner rescan ng-undupe ng-chown $(bindir)/; fi
+	if [ -e $(bindir) ]; then cp -f zipscript-c postdel racestats cleanup datacleaner rescan ng-undupe ng-chown audiosort $(bindir)/; fi
 
 distclean: clean
 
 clean:
-	$(RM) zipscript-c postdel racestats cleanup datacleaner rescan ng-undupe ng-chown
+	$(RM) zipscript-c postdel racestats cleanup datacleaner rescan ng-undupe ng-chown audiosort
 
 uninstall:
 	rm -rf "$(prefix)$(storage)"
-	rm -f $(bindir)/{zipscript-c,postdel,racestats,cleanup,datacleaner,rescan,ng-undupe,ng-chown}
+	rm -f $(bindir)/{zipscript-c,postdel,racestats,cleanup,datacleaner,rescan,ng-undupe,ng-chown,audiosort}
 
 strip:
-	strip zipscript-c postdel racestats cleanup datacleaner rescan ng-undupe ng-chown
+	strip zipscript-c postdel racestats cleanup datacleaner rescan ng-undupe ng-chown audiosort
Index: zipscript/src/zipscript-c.c
===================================================================
--- zipscript/src/zipscript-c.c	(revision 1811)
+++ zipscript/src/zipscript-c.c	(working copy)
@@ -38,6 +38,7 @@
 #include "complete.h"
 #include "crc.h"
 #include "ng-version.h"
+#include "audiosort.h"
 
 #include "../conf/zsconfig.h"
 #include "../include/zsconfig.defaults.h"
@@ -224,8 +225,8 @@
 	g.l.sfv = ng_realloc2(g.l.sfv, n, 1, 1, 1);
 	g.l.leader = ng_realloc2(g.l.leader, n, 1, 1, 1);
 	target = ng_realloc2(target, n + 256, 1, 1, 1);
-	g.ui = ng_realloc2(g.ui, sizeof(struct USERINFO *) * 30, 1, 1, 1);
-	g.gi = ng_realloc2(g.gi, sizeof(struct GROUPINFO *) * 30, 1, 1, 1);
+	g.ui = ng_realloc2(g.ui, sizeof(struct USERINFO *) * 100, 1, 1, 1);
+	g.gi = ng_realloc2(g.gi, sizeof(struct GROUPINFO *) * 100, 1, 1, 1);
 
 	d_log("zipscript-c: Copying data g.l into memory\n");
 	sprintf(g.l.sfv, storage "/%s/sfvdata", g.l.path);
@@ -964,7 +965,7 @@
 #if ( audio_cbr_check == TRUE )
 						if (g.v.audio.is_vbr == 0) {
 							if (!strcomp(allowed_constant_bitrates, g.v.audio.bitrate)) {
-								d_log("zipscript-c: File is encoded using banned bitrate\n");
+								d_log("zipscript-c: File is encoded using banned bitrate (%d)\n", g.v.audio.bitrate);
 								sprintf(g.v.misc.error_msg, BANNED_BITRATE, g.v.audio.bitrate);
 								if (audio_cbr_warn == TRUE) {
 									if (g.ui[g.v.user.pos]->files == 1) {
@@ -1293,42 +1294,10 @@
 				if (!strncasecmp(g.l.link_target, "VA", 2) && (g.l.link_target[2] == '-' || g.l.link_target[2] == '_'))
 					memcpy(g.v.audio.id3_artist, "VA", 3);
 
-				if (g.v.misc.write_log == TRUE && !matchpath(group_dirs, g.l.path)) {
-#if ( audio_genre_sort == TRUE )
-					d_log("zipscript-c:   Sorting mp3 by genre (%s)\n", g.v.audio.id3_genre);
-					createlink(audio_genre_path, g.v.audio.id3_genre, g.l.link_source, g.l.link_target);
-#endif
-#if ( audio_artist_sort == TRUE )
-					d_log("zipscript-c:   Sorting mp3 by artist\n");
-					if (*g.v.audio.id3_artist) {
-						d_log("zipscript-c:     - artist: %s\n", g.v.audio.id3_artist);
-						if (memcmp(g.v.audio.id3_artist, "VA", 3)) {
-							temp_p = ng_realloc(temp_p, 2, 1, 1, &g.v, 1);
-							snprintf(temp_p, 2, "%c", toupper(*g.v.audio.id3_artist));
-							createlink(audio_artist_path, temp_p, g.l.link_source, g.l.link_target);
-							ng_free(temp_p);
-						} else {
-							createlink(audio_artist_path, "VA", g.l.link_source, g.l.link_target);
-						}
-					}
-#endif
-#if ( audio_year_sort == TRUE )
-					d_log("zipscript-c:   Sorting mp3 by year (%s)\n", g.v.audio.id3_year);
-					if (*g.v.audio.id3_year != 0) {
-						createlink(audio_year_path, g.v.audio.id3_year, g.l.link_source, g.l.link_target);
-					}
-#endif
-#if ( audio_group_sort == TRUE )
-					d_log("zipscript-c:   Sorting mp3 by group\n");
-					temp_p = remove_pattern(g.l.link_target, "*-", RP_LONG_LEFT);
-					temp_p = remove_pattern(temp_p, "_", RP_SHORT_LEFT);
-					n = (int)strlen(temp_p);
-					if (n > 0 && n < 15) {
-						d_log("zipscript-c:   - Valid groupname found: %s (%i)\n", temp_p, n);
-						createlink(audio_group_path, temp_p, g.l.link_source, g.l.link_target);
-					}
-#endif
-				}
+				/* Sort if we're s'posed to write to log and we're not in a group-dir. */
+				if (g.v.misc.write_log == TRUE && !matchpath(group_dirs, g.l.path))
+						audioSort(&g.v.audio, g.l.link_source, g.l.link_target);
+
 #if ( create_m3u == TRUE )
 				if (findfileext(dir, ".sfv")) {
 					d_log("zipscript-c: Creating m3u\n");
Index: zipscript/src/complete.c
===================================================================
--- zipscript/src/complete.c	(revision 1811)
+++ zipscript/src/complete.c	(working copy)
@@ -128,26 +128,49 @@
 void 
 writetop(GLOBAL *g, int completetype)
 {
-	int		cnt = 0;
+	int		cnt, mlen, mset, mtemp;
 	char		templine [FILE_MAX];
 	char	       *buffer = 0;
+	char	       *pbuf = 0;
 
 	if (completetype == 1) {
 		if (user_top != NULL) {
-			buffer = templine;
+			mlen = 0;
+			mset = 1;
+			pbuf = buffer = ng_realloc(buffer, FILE_MAX, 1, 1, &g->v, 1);
 			for (cnt = 0; cnt < max_users_in_top && cnt < g->v.total.users; cnt++) {
-				buffer += sprintf(buffer, "%s ", convert2(&g->v, g->ui[g->ui[cnt]->pos], g->gi, user_top, cnt));
+				snprintf(templine, FILE_MAX, "%s ", convert2(&g->v, g->ui[g->ui[cnt]->pos], g->gi, user_top, cnt));
+				mlen = strlen(templine);
+				if ((int)strlen(buffer) + mlen >= FILE_MAX * mset) {
+					mset += 1;
+					mtemp = pbuf - buffer;
+					buffer = ng_realloc(buffer, FILE_MAX * mset, 0, 1, &g->v, 0);
+					pbuf = buffer + mtemp;
+				}
+				memcpy(pbuf, templine, mlen);
+				pbuf += mlen;
 			}
-			*buffer -= '\0';
-			writelog(g, templine, stat_users_type);
+			*pbuf -= '\0';
+			writelog(g, buffer, stat_users_type);
+			ng_free(buffer);
 		}
 		if (group_top != NULL) {
-			buffer = templine;
+			mlen = 0;
+			mset = 1;
+			pbuf = buffer = ng_realloc(buffer, FILE_MAX, 1, 1, &g->v, 1);
 			for (cnt = 0; cnt < max_groups_in_top && cnt < g->v.total.groups; cnt++) {
-				buffer += sprintf(buffer, "%s ", convert3(&g->v, g->gi[g->gi[cnt]->pos], group_top, cnt));
+				snprintf(templine, FILE_MAX, "%s ", convert3(&g->v, g->gi[g->gi[cnt]->pos], group_top, cnt));
+				mlen = strlen(templine);
+				if ((int)strlen(buffer) + mlen >= FILE_MAX * mset) {
+					mset += 1;
+					buffer = ng_realloc(buffer, FILE_MAX * mset, 0, 1, &g->v, 0);
+				}
+				memcpy(pbuf, templine, mlen);
+				pbuf += mlen;
 			}
-			*buffer -= '\0';
-			writelog(g, templine, stat_groups_type);
+			*pbuf -= '\0';
+			writelog(g, buffer, stat_groups_type);
+			ng_free(buffer);
 		}
 		if (post_stats != NULL) {
 			writelog(g, convert(&g->v, g->ui, g->gi, post_stats), stat_post_type);
Index: zipscript/src/dizreader.c
===================================================================
--- zipscript/src/dizreader.c	(revision 1811)
+++ zipscript/src/dizreader.c	(working copy)
@@ -29,7 +29,8 @@
 		"[!!/#]",
 		": ?!/##&/",
 		"xx/##",
-		"<!!/##>"};
+		"<!!/##>",
+		"x/##"};
 
 int		strings = 16;
 
Index: zipscript/src/postdel.c
===================================================================
--- zipscript/src/postdel.c	(revision 1811)
+++ zipscript/src/postdel.c	(working copy)
@@ -244,8 +244,8 @@
 	name_p++;
 
 	if (temp_p) {
-		if (sizeof(temp_p) - 4 > 0)
-			temp_p = temp_p + sizeof(temp_p) - 4;
+		while ((signed)strlen(temp_p) - 4 > 0)
+			temp_p++;
 		snprintf(fileext, 4, "%s", temp_p);
 	} else
 		*fileext = '\0';
@@ -411,7 +411,7 @@
 		break;
 	}
 
-	if (empty_dir == 1) {
+	if (empty_dir == 1 && !findfileext(dir, ".sfv")) {
 		
 		d_log("postdel: Removing all files and directories created by zipscript\n");
 		if (del_completebar)
Index: zipscript/src/mp3info.c
===================================================================
--- zipscript/src/mp3info.c	(revision 1811)
+++ zipscript/src/mp3info.c	(working copy)
@@ -373,7 +373,7 @@
 		}
 	}
 	fclose(mp3.file);
-	if (mp3.vbr)
+	if (mp3.vbr || *audio->bitrate == '0')
 		sprintf(audio->bitrate, "%.0f", (mp3.vbr_average));
 //	audio->is_vbr = mp3.vbr;
 //	return mp3.vbr_average;
Index: zipscript/src/rescan.c
===================================================================
--- zipscript/src/rescan.c	(revision 1811)
+++ zipscript/src/rescan.c	(working copy)
@@ -19,6 +19,7 @@
 #include "complete.h"
 #include "crc.h"
 #include "ng-version.h"
+#include "audiosort.h"
 
 #include "../conf/zsconfig.h"
 #include "../include/zsconfig.defaults.h"
@@ -329,6 +330,8 @@
 				strcpy(exec + n - 3, "m3u");
 				create_indexfile(g.l.race, &g.v, exec);
 #endif
+				audioSort(&g.v.audio, g.l.link_source, g.l.link_target);
+				printf(" Resorting release.\n");
 				break;
 			case RTYPE_VIDEO:
 				complete_bar = video_completebar;
Index: zipscript/src/ng-chown.c
===================================================================
--- zipscript/src/ng-chown.c	(revision 1811)
+++ zipscript/src/ng-chown.c	(working copy)
@@ -277,9 +277,9 @@
 				while (f_buf[m] != ':' && m > l_start)
 					m--;
 #if (change_spaces_to_underscore_in_ng_chown)
-				if ((m != i) && ((int)strlen(u_name) == (int)strlen(user_name)) && !strcmp(u_name, u_modname)){
+				if ((m != i) && !strcmp(u_name, u_modname)){
 #else
-				if ((m != i) && ((int)strlen(u_name) == (int)strlen(user_name)) && !strcmp(u_name, user_name)){
+				if ((m != i) && !strcmp(u_name, user_name)){
 #endif
 					u_id = strtol(f_buf + m + 1, NULL, 10);
 					break;
@@ -340,9 +340,9 @@
 				while (f_buf[m] != ':' && m > l_start)
 					m--;
 #if (change_spaces_to_underscore_in_ng_chown)
-				if ((m != i) && ((int)strlen(g_name) == (int)strlen(group_name)) && !strcmp(g_name, g_modname)){
+				if ((m != i) && !strcmp(g_name, g_modname)){
 #else
-				if ((m != i) && ((int)strlen(g_name) == (int)strlen(group_name)) && !strcmp(g_name, group_name)){
+				if ((m != i) && !strcmp(g_name, group_name)){
 #endif
 					g_id = strtol(f_buf + m + 1, NULL, 10);
 					break;
Index: zipscript/src/zsfunctions.c
===================================================================
--- zipscript/src/zsfunctions.c	(revision 1811)
+++ zipscript/src/zsfunctions.c	(working copy)
@@ -669,6 +669,7 @@
 	int		l1 = (int)strlen(factor1) + 1,
 			l2 = (int)strlen(factor2) + 1,
 			l3 = (int)strlen(ltarget) + 1;
+	struct stat linkStat;
 
 	memcpy(target, factor1, l1);
 	target += l1 - 1;
@@ -689,8 +690,16 @@
 	memcpy(target, ltarget, l3);
 
 #if ( userellink == 1 )
+# if ( delete_old_link == TRUE )
+	if (lstat(result, &linkStat) != -1 && S_ISLNK(linkStat.st_mode))
+			unlink(result);
+# endif
 	symlink(result, org);
 #else
+# if ( delete_old_link == TRUE )
+	if (lstat(source, &linkStat) != -1 && S_ISLNK(linkStat.st_mode))
+			unlink(source);
+# endif
 	symlink(source, org);
 #endif
 }
Index: zipscript/src/race-file.c
===================================================================
--- zipscript/src/race-file.c	(revision 1811)
+++ zipscript/src/race-file.c	(working copy)
@@ -531,7 +531,8 @@
 				skip = 0;
 				lseek(outfd, 0L, SEEK_SET);
 				while (read(outfd, &tempsd, sizeof(SFVDATA)))
-					if ((!strcmp(sd.fname, tempsd.fname) && strlen(sd.fname) == strlen(tempsd.fname)) || ( sd.crc32 == tempsd.crc32 && sd.crc32))
+//					if (!strcmp(sd.fname, tempsd.fname) || (sd.crc32 == tempsd.crc32 && sd.crc32))
+					if (!strcmp(sd.fname, tempsd.fname))
 						skip = 1;
 						
 				lseek(outfd, 0L, SEEK_END);
@@ -920,9 +921,10 @@
 int
 create_lock(struct VARS *raceI, const char *path, unsigned int progtype, unsigned int force_lock, unsigned int queue)
 {
-	int		fd;
+	int		fd, cnt;
 	HEADDATA	hd;
-	struct stat	sb;
+	struct stat	sp, sb;
+	char		lockfile[PATH_MAX + 1];
 
 	/* this should really be moved out of the proc - we'll worry about it later */
 	snprintf(raceI->headpath, PATH_MAX, "%s/%s/headdata", storage, path);
@@ -934,6 +936,19 @@
 
 	fstat(fd, &sb);
 
+	snprintf(lockfile, PATH_MAX, "%s.lock", raceI->headpath);
+	if (!stat(lockfile, &sp) && (time(NULL) - sp.st_ctime >= max_seconds_wait_for_lock * 5))
+		unlink(lockfile);
+	cnt = 0;
+	while (cnt < 10 && link(raceI->headpath, lockfile)) {
+		d_log("create_lock: link failed (%d/10) - sleeping .1 seconds: %s\n", cnt, strerror(errno));
+		cnt++;
+		usleep(100000);
+	}
+	if (cnt == 10 ) {
+		d_log("create_lock: link failed: %s\n", strerror(errno));
+		return -1;
+	}
 	if (!sb.st_size) {							/* no lock file exists - let's create one with default values. */
 		hd.data_version = sfv_version;
 		raceI->data_type = hd.data_type = 0;
@@ -952,6 +967,7 @@
 		if (hd.data_version != sfv_version) {
 			d_log("create_lock: version of datafile mismatch. Stopping and suggesting a cleanup.\n");
 			close(fd);
+			unlink(lockfile);
 			return 1;
 		}
 		if ((time(NULL) - sb.st_ctime >= max_seconds_wait_for_lock * 5)) {
@@ -1004,6 +1020,7 @@
 					d_log("create_lock: write failed: %s\n", strerror(errno));
 				close(fd);
 				d_log("create_lock: putting you in queue. (%d/%d)\n", hd.data_qcurrent, hd.data_queue);
+				unlink(lockfile);
 				return -1;
 			} else if (hd.data_queue && (queue > hd.data_qcurrent) && !force_lock) {
 										/* seems there is a queue, and the calling process' place in */
@@ -1011,6 +1028,7 @@
 				raceI->data_incrementor = hd.data_incrementor;	/* feed back the current incrementor */
 				raceI->misc.release_type = hd.data_type;
 				close(fd);
+				unlink(lockfile);
 				return -1;
 			}
 		}
@@ -1042,6 +1060,7 @@
 {
 	int		fd;
 	HEADDATA	hd;
+	char		lockfile[PATH_MAX + 1];
 
 	if ((fd = open(raceI->headpath, O_RDWR, 0666)) == -1) {
 		d_log("remove_lock: open(%s): %s\n", raceI->headpath, strerror(errno));
@@ -1064,6 +1083,8 @@
 		if (write(fd, &hd, sizeof(HEADDATA)) != sizeof(HEADDATA))
 			d_log("remove_lock: write failed: %s\n", strerror(errno));
 		close(fd);
+		snprintf(lockfile, PATH_MAX, "%s.lock", raceI->headpath);
+		unlink(lockfile);
 		d_log("remove_lock: queue %d/%d\n", hd.data_qcurrent, hd.data_queue);
 	}
 }
Index: zipscript/src/multimedia.c
===================================================================
--- zipscript/src/multimedia.c	(revision 1811)
+++ zipscript/src/multimedia.c	(working copy)
@@ -5,6 +5,7 @@
 #include "mp3info.h"
 #include "objects.h"
 #include "multimedia.h"
+#include "zsfunctions.h"
 
 char *genre_s[] = {
 	"Blues", "Classic Rock", "Country", "Dance",
@@ -240,7 +241,18 @@
 	int		t1;
 
 	fd = open(f, O_RDONLY);
+	if (fd < 0)
+	{
+		d_log("get_mpeg_audio_info: could not open file '%s': %s\n", f, strerror(errno));
+		strcpy(audio->id3_year, "0000");
+		strcpy(audio->id3_title, "Unknown");
+		strcpy(audio->id3_artist, "Unknown");
+		strcpy(audio->id3_album, "Unknown");
+		audio->id3_genre = genre_s[148];
 
+		return;
+	}
+
 	n = 2;
 	while (read(fd, header + 2 - n, n) == n) {
 		if (*header == 255) {

Property changes on: zipscript/src
___________________________________________________________________
Name: svn:ignore
   - Makefile
racestats
ng-undupe
zipscript-c
ng-chown
racedebug
cleanup
datacleaner
postdel
rescan

   + Makefile
racestats
ng-undupe
zipscript-c
ng-chown
racedebug
cleanup
datacleaner
postdel
rescan
audiosort


Index: README
===================================================================
--- README	(revision 1811)
+++ README	(working copy)
@@ -225,7 +225,7 @@
 here's what to do:
 
            cp -f zipscript-c postdel racestats cleanup datacleaner rescan \
-	         racedebug ng-undupe ng-chown /path/to/your/glftpd/bin/
+	         racedebug ng-undupe ng-chown audiosort /path/to/your/glftpd/bin/
            chmod 666 /path/to/your/glftpd/ftp-data/logs/glftpd.log
            mkdir -pm777 /path/to/your/glftpd/ftp-data/pzs-ng
 (optional) chmod +s /path/to/your/glftpd/bin/zipscript-c
@@ -293,13 +293,18 @@
 site_cmd	RESCAN			EXEC	/bin/rescan
 custom-rescan	!8	*
 
-The first two will remove dead symlinks. The last two will allow you (and all
+site_cmd	AUDIOSORT		EXEC	/bin/audiosort
+custom-audiosort	!8	*
+
+The first two will remove dead symlinks. The next two will allow you (and all
 users except anon users) to rescan a dir. This comes in handy in places the
 zipscript isn't invoked by default, when you have dirs you wish to check filled
-before you added the zipscript, and a lot of other occations.
+before you added the zipscript, and a lot of other occations. 
 Forget to add this and you will hit yourself hard quite a few times. ;)
+The last allows you to only resort the genres/year/group/artist of an mp3-release. 
+(rescan does the same, but audiosort is faster - it doesn't check the crc and 
+such of the release)
 
-
 Crontab:
 --------
 All that's left now is to tie up some loose ends - and installing the bot,
Index: FAQ
===================================================================
--- FAQ	(revision 1811)
+++ FAQ	(working copy)
@@ -111,3 +111,10 @@
       /glftpd/bin/stats -r /etc/glftpd.conf -u -a -s <your section here>
    This should give some indication of where the problem is.
 
+Q: (BOT) I get error on !wkup etc. I use a cryptscript.
+-------------------------------------------------------
+A: Change your cryptscript. Currently known working script is mircryption
+   http://mircryption.sourceforge.net
+   Not verified, but told is working is poci's cryptscript.
+   http://poci.u5-inside.de/
+
Index: sitebot/plugins/DeluserBan.tcl
===================================================================
--- sitebot/plugins/DeluserBan.tcl	(revision 1811)
+++ sitebot/plugins/DeluserBan.tcl	(working copy)
@@ -119,7 +119,7 @@
     ## Create a ban mask for the user.
     set userHost [getchanhost $ircUser]
     if {[string equal "" $userHost]} {
-        set userHost "$ircUser!*@*"
+        set userHost "*@*"
     }
 
     ## Kick/ban the user from all channels.
@@ -129,7 +129,7 @@
             putkick $channel $ircUser $reason
         }
         if {[IsTrue $banUser]} {
-            newchanban $channel $userHost $botnick $reason
+            newchanban $channel $ircUser!$userHost $botnick $reason
         }
     }
 
Index: sitebot/themes/default.zst
===================================================================
--- sitebot/themes/default.zst	(revision 1811)
+++ sitebot/themes/default.zst	(working copy)
@@ -220,7 +220,7 @@
 announce.LEECH                  = "[%b{bwinfo}] Current leechers:"
 announce.UPLOAD                 = "[%b{bwinfo}] Current uploaders:"
 announce.IDLE                   = "[%b{bwinfo}] Current idlers:"
-announce.BW                     = "[%b{bwinfo}] %b{%uploads} up at %upspeed (%uppercent%) :: %b{%downloads} down at %dnspeed (%dnpercent%) %b{%transfers} in total at %totalspeed (%totalpercent%) :: %b{%active} browsing :: %b{%idlers} idle :: %b{%totallogins} out of %b{%maxusers} in total."
+announce.BW                     = "[%b{bwinfo}] %b{%uploads} up at %upspeed (%uppercent%) :: %b{%downloads} down at %dnspeed (%dnpercent%) :: %b{%transfers} in total at %totalspeed (%totalpercent%) :: %b{%active} browsing :: %b{%idlers} idle :: %b{%totallogins} out of %b{%maxusers} in total."
 announce.BWUP                   = "[%b{bwinfo}] %b{%uploads} uploads @ %upspeed (%uppercent%)."
 announce.BWDN                   = "[%b{bwinfo}] %b{%downloads} downloads @ %dnspeed (%dnpercent%)."
 announce.TOTUPDN                = "[%b{bwinfo}] %type %b{%count} at %b{%total} (%b{%per}%)."
Index: sitebot/themes/dakrer.zst
===================================================================
--- sitebot/themes/dakrer.zst	(revision 1811)
+++ sitebot/themes/dakrer.zst	(working copy)
@@ -245,7 +245,7 @@
 announce.LEECH					= "[%b{LEECHERS}] Current leechers:"
 announce.UPLOAD					= "[%b{UPLOADERS}] Current uploaders:"
 announce.IDLE					= "[%b{IDLERS}] Current idlers:"
-announce.BW					= "[%b{BW}] %b{%uploads} up at %upspeed (%uppercent%) :: %b{%downloads} down at %dnspeed (%dnpercent%) %b{%transfers} in total at %totalspeed (%totalpercent%) :: %b{%active} browsing :: %b{%idlers} idle :: %b{%totallogins} in total"
+announce.BW					= "[%b{BW}] %b{%uploads} up at %upspeed (%uppercent%) :: %b{%downloads} down at %dnspeed (%dnpercent%) :: %b{%transfers} in total at %totalspeed (%totalpercent%) :: %b{%active} browsing :: %b{%idlers} idle :: %b{%totallogins} in total"
 announce.BWUP					= "[%b{BW}] %b{%uploads} uploads @ %upspeed (%uppercent%)"
 announce.BWDN					= "[%b{BW}] %b{%downloads} downloads @ %dnspeed (%dnpercent%)"
 announce.TOTUPDN				= "[%b{BW}] %type %b{%count} at %total (%b{%per}%)"
Index: sitebot/dZSbot.tcl
===================================================================
--- sitebot/dZSbot.tcl	(revision 1811)
+++ sitebot/dZSbot.tcl	(working copy)
@@ -273,7 +273,7 @@
 		## The regex pattern to use for the logfile
 		switch -exact -- $logtype {
 			0 {set regex {^.+ \d+:\d+:\d+ \d{4} (\S+): (.+)}}
-			1 - 2 {set regex {^.+ \d+:\d+:\d+ \d{4} \[(.+)\] (.+)}}
+			1 - 2 {set regex {^.+ \d+:\d+:\d+ \d{4} \[(\d+)\s*\] (.+)}}
 			default {putlog "dZSbot error: Internal error, unknown log type ($logtype)."; continue}
 		}
 		## Read the log data
@@ -589,16 +589,16 @@
 
 proc format_duration {secs} {
 	set duration ""
-	foreach div {31536000 604800 86400 3600 60 1} mod {0 52 7 24 60 60} unit {y w d h m s} {
+	foreach div {31536000 604800 86400 3600 60 1} unit {y w d h m s} {
 		set num [expr {$secs / $div}]
-		if {$mod > 0} {set num [expr {$num % $mod}]}
 		if {$num > 0} {lappend duration "\002$num\002$unit"}
+		set secs [expr {$secs % $div}]
 	}
 	if {[llength $duration]} {return [join $duration]} else {return "\0020\002s"}
 }
 
 proc format_kb {amount} {
-	foreach dec {0 1 2 2 2} unit {KB MB GB TB PB} {
+	foreach dec {0 1 2 2 2} unit {KB MB GB TB PB EB} {
 		if {abs($amount) >= 1024} {
 			set amount [expr {double($amount) / 1024.0}]
 		} else {break}
@@ -1075,11 +1075,11 @@
 	set devCount 0; set lineCount 0
 	set totalFree 0; set totalUsed 0; set totalSize 0
 
-	foreach line [split [exec $binary(DF) "-Pk"] "\n"] {
+	foreach line [split [exec $binary(DF) "-Pkl"] "\n"] {
 		foreach {name value} [array get tmpdev] {
 			if {[string equal [lindex $line 0] [lindex $value 0]]} {
 				if {[llength $line] < 4} {
-					putlog "dZSbot warning: Invalid \"df -Pk\" line: $line"
+					putlog "dZSbot warning: Invalid \"df -Pkl\" line: $line"
 					continue
 				}
 				foreach {devName devSize devUsed devFree} $line {break}
@@ -1115,7 +1115,7 @@
 	if {[llength [array names tmpdev]]} {
 		set devList ""
 		foreach {name value} [array get tmpdev] {lappend devList $value}
-		putlog "dZSbot warning: The following devices had no matching \"df -Pk\" entry: [join $devList {, }]"
+		putlog "dZSbot warning: The following devices had no matching \"df -Pkl\" entry: [join $devList {, }]"
 	}
 
 	if {$totalSize} {
@@ -1922,10 +1922,11 @@
 
 ## Load the theme file
 if {![loadtheme $announce(THEMEFILE)]} {
+	set invalidTheme $announce(THEMEFILE)
 	if {[loadtheme "themes/default.zst"]} {
-		putlog "dZSbot warning: Unable to load theme $announce(THEMEFILE), loaded default.zst instead."
+		putlog "dZSbot warning: Unable to load theme $invalidTheme, loaded default.zst instead."
 	} else {
-		putlog "dZSbot error: Unable to load the themes $announce(THEMEFILE) and default.zst."
+		putlog "dZSbot error: Unable to load the themes $invalidTheme and default.zst."
 		set dzerror 1
 	}
 }
Index: README.ZSCONFIG
===================================================================
--- README.ZSCONFIG	(revision 1811)
+++ README.ZSCONFIG	(working copy)
@@ -450,7 +450,7 @@
 	Default: "/site/incoming/music.by.year/"
 
 audio_group_sort <TRUE|FALSE>
-	If you wish to sort aduio/mp3 releases by group, set this to TRUE.
+	If you wish to sort audio/mp3 releases by group, set this to TRUE.
 	Default: FALSE
 
 audio_group_path <PATH>
@@ -459,6 +459,13 @@
 	for the sorting to work - the zipscript will not create it for you.
 	Default: "/site/incoming/music.by.group/"
 
+delete_old_link <TRUE|FALSE>
+	If you do NOT want to have the zipscript/rescan/audiosort delete any
+	links with the same name when it tries to create a new link, set this 
+	to FALSE. This will cause rescan / audiosort to be useless if there
+	already are sortedlinks for this release.
+	Default: TRUE
+
 allowed_constant_bitrates <STRING>
 	You can restrict uploaded audio/mp3 releases several ways. One is by
 	bitrate. Only CBR (Constant Bit Rate) mp3-files is of interest this
@@ -706,7 +713,7 @@
 	When files are uploaded, some output is shown to the racer uploading.
 	Put here what should be shown as the body of that message on any ok
 	file.
-	Default: "| + File: ok!                                      |\n"
+	Default: "| + File: ok! (allowed w/o any checks)             |\n"
 
 zipscript_SFV_ok <STRING>
 	When files are uploaded, some output is shown to the racer uploading.
