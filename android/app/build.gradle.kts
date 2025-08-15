plugins {
    id("com.android.application")
    id("com.google.gms.google-services")     // Firebase Google Services
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ebrardilruba.refa"

    // Flutter tarafından sağlanan SDK sürümleri
    compileSdk = flutter.compileSdkVersion

    // NDK (senin projen böyle kullanıyor)
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.ebrardilruba.refa"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // .so sembollerini koru (senin ayarın)
    packaging {
        jniLibs {
            keepDebugSymbols += setOf("**/*.so")
        }
    }

    buildTypes {
        debug {
            ndk { debugSymbolLevel = "NONE" }
        }
        release {
            // mağazaya çıkarken kendi imzanı koy
            signingConfig = signingConfigs.getByName("debug")
            // istersen minify/proguard vb. burada açarsın
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
