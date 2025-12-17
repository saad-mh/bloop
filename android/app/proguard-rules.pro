# Keep generic type information and notification storage classes to avoid
# "Missing type parameter" crashes when flutter_local_notifications persists schedules.
-keepattributes Signature
-keepattributes *Annotation*

# flutter_local_notifications plugin classes (Gson serialization of scheduled notifications)
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# Gson TypeToken requires the generic signature to remain
-keep class com.google.gson.reflect.TypeToken
-keep class * extends com.google.gson.reflect.TypeToken
