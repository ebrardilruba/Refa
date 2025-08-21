plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Firebase
}

android {
    namespace = "com.refa.app"

    // Flutter plugin'in sağladığı değerler
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.refa.app"
        minSdk = flutter.minSdkVersion   // (doğru: Kotlin DSL'de minSdk)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions { jvmTarget = "17" }

    packaging {
        jniLibs {
            keepDebugSymbols += setOf("**/*.so")
        }
    }

    buildTypes {
        getByName("debug") {
            ndk { debugSymbolLevel = "NONE" }
        }
        getByName("release") {
            // ---- R8/ProGuard + shrink ----
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Test için debug keystore ile imza (kendi release imzan varsa onu kullan)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Java 8+ API'lerini eski Android'lerde kullanmak için
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // ---- ML Kit Text Recognition ----
    // Sadece Latin + (isteğe bağlı) Devanagari ve Korece
    implementation("com.google.mlkit:text-recognition:16.0.1")          // Latin
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")

    // *** İSTEK ÜZERİNE KALDIRILDI: Çince ve Japonca ***
    // implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    // implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
}
