# R8 runs over the Java and Kotlin half of the app only: everything written
# in Dart is compiled ahead of time into libapp.so and is not visible here.
#
# Firebase, Firestore and the Flutter engine all ship their own keep rules
# inside their artifacts, so this file covers only what is ours.

# The home-screen widget is reached by name, never by a call: the launcher
# builds the receiver from the manifest entry, and the layout inflates the
# views. Manifest components survive R8 on their own, but the constants and
# the helpers it keeps beside them are only referenced from there.
-keep class com.baboevazamatkz.expense_tracker.SolidusWidgetProvider { *; }

# Keeps the line numbers in a crash report meaningful. Without it a stack
# trace from Play Console points at obfuscated names with no line numbers,
# and the mapping file is the only way back.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
