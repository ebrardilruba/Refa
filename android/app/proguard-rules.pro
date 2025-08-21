# ML Kit sınıflarını koru
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# İç ML Kit paketleri uyarı verirse sustur (keep yok, APK şişmesin)
-dontwarn com.google.android.gms.internal.mlkit_**
