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
        minSdk = flutter.minSdkVersion  // minSdkVersion değil, minSdk olmalı
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
    
    packaging {
        jniLibs { 
            keepDebugSymbols += setOf("**/*.so") 
        }
    }
    
    buildTypes {
        debug { 
            ndk { 
                debugSymbolLevel = "NONE" 
            } 
        }
        release { 
            signingConfig = signingConfigs.getByName("debug") 
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}