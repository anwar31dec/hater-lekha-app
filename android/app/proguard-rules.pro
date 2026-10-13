# Crashlytics: keep file names and line numbers so stack traces stay readable with R8.
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
