# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class com.google.firebase.** { *; }

# DataStore
-keep class androidx.datastore.** { *; }

# Supabase / GoTrue / HTTP
-keep class io.github.jan.supabase.** { *; }
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature,Annotation,InnerClasses

# Flutter Image Compress
-keep class com.fluttercandies.flutter_image_compress.** { *; }

# Camera
-keep class androidx.camera.core.** { *; }
-keep class androidx.camera.camera2.** { *; }
-keep class androidx.camera.lifecycle.** { *; }
-keep class androidx.camera.video.** { *; }

# Google Play Core (referenced by Flutter Engine for deferred components)
-dontwarn com.google.android.play.core.**

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
