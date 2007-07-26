# A simple patch for pzs-ng v1.0.1
# This will fix a small bug with the deletion of old symlinks for audiosorting! :)
#
# How to apply:
# cd to the main dir of pzs-ng sources
# patch -p0 </path/to/pzs-ng_v1.0.1b_patch.diff
#
# There should be no errors.
#

Index: zipscript/src/zsfunctions.c
===================================================================
--- zipscript/src/zsfunctions.c	(revision 2039)
+++ zipscript/src/zsfunctions.c	(revision 2040)
@@ -689,17 +689,14 @@
 
 	memcpy(target, ltarget, l3);
 
-#if ( userellink == 1 )
 # if ( delete_old_link == TRUE )
-	if (lstat(result, &linkStat) != -1 && S_ISLNK(linkStat.st_mode))
-			unlink(result);
+	if (lstat(org, &linkStat) != -1 && S_ISLNK(linkStat.st_mode))
+		unlink(org);
 # endif
+
+#if ( userellink == 1 )
 	symlink(result, org);
 #else
-# if ( delete_old_link == TRUE )
-	if (lstat(source, &linkStat) != -1 && S_ISLNK(linkStat.st_mode))
-			unlink(source);
-# endif
 	symlink(source, org);
 #endif
 }
