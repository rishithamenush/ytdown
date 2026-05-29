-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.antonkarpenko.ffmpegkit.FFmpegKitConfig {
    native <methods>;
    void log(long, int, byte[]);
    void statistics(long, int, float, float, long , double, double, double);
    int safOpen(int);
    int safClose(int);
}
-keep class com.antonkarpenko.ffmpegkit.AbiDetect {
    native <methods>;
}
-keep class com.snnafi.media_store_plus.** { *; }

# Flutter foreground task — entry-points are reflectively invoked.
-keep class com.pravera.flutter_foreground_task.** { *; }

# Strip verbose logging to slim runtime memory + apk size.
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
    public static *** i(...);
}

# General Flutter / plugin safety nets (registrants are reflective).
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**
