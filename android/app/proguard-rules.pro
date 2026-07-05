# iConvert ProGuard Rules

# 缺失类（Play Core 不在依赖中但 Flutter 引擎引用了）
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# FFmpegKit
-keep class com.arthenica.** { *; }
-keep class com.antonkarpenko.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# flutter_foreground_task
-keep class com.pravera.flutter_foreground_task.** { *; }

# image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# just_audio
-keep class com.ryanheise.just_audio.** { *; }

# video_player
-keep class io.flutter.plugins.videoplayer.** { *; }

# chewie
-keep class com.brianegan.chewie.** { *; }

# open_filex
-keep class com.llfbandit.open_filex.** { *; }

# liquid_glass_easy
-keep class com.example.liquid_glass_easy.** { *; }

# shared_preferences
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# url_launcher
-keep class io.flutter.plugins.urllauncher.** { *; }

# quick_actions
-keep class io.flutter.plugins.quickactions.** { *; }

# flutter_device_apps
-keep class com.example.flutter_device_apps.** { *; }

# 保留所有 native 方法
-keepclasseswithmembernames class * {
    native <methods>;
}

# 保留 Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator CREATOR;
}

# 保留枚举
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
