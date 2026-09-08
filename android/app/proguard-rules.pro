# Keep Flutter's generated entry points and plugin registration intact while
# R8 removes Java and Kotlin code that the app never calls.
-keep class io.flutter.embedding.engine.plugins.** { *; }
-keep class io.flutter.plugins.GeneratedPluginRegistrant { *; }

