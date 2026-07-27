# WorkManager / Room release crash fix:
# "Failed to create an instance of androidx.work.impl.WorkDatabase"
-keep class androidx.work.** { *; }
-keep class androidx.room.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**

# flutter_local_notifications release crash fix: "Missing type parameter."
-keep class com.dexterous.** { *; }
-keep class * extends com.dexterous.flutterlocalnotifications.models.NotificationDetails
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.dexterous.**
