# Keep only Latin/English ML Kit artifact in dependencies.
# The plugin references other script option classes; these are optional and
# intentionally absent to reduce app size.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
