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

# Supabase / GoTrue
-keep class io.github.jan.supabase.** { *; }

# Image Cropper
-keep class com.yalantis.ucrop.** { *; }

# Camera
-keep class androidx.camera.core.** { *; }

# Preserve line numbers for crash reporting
-keepattributes SourceFile,LineNumberTable
