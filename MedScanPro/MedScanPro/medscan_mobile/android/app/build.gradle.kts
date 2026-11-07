import java.io.File

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Read gitignored .env for local development/evaluation so Android Studio's Run button
// works automatically without requiring manual --dart-define CLI flags.
val envFile = File(rootProject.projectDir.parentFile, ".env")
var localGeminiKey = ""
var localMapboxToken = ""
if (envFile.exists()) {
    envFile.forEachLine { line ->
        val trimmed = line.trim()
        if (trimmed.startsWith("GEMINI_API_KEY=")) {
            localGeminiKey = trimmed.substringAfter("GEMINI_API_KEY=").trim().removeSurrounding("\"")
        } else if (trimmed.startsWith("MAPBOX_ACCESS_TOKEN=")) {
            localMapboxToken = trimmed.substringAfter("MAPBOX_ACCESS_TOKEN=").trim().removeSurrounding("\"")
        }
    }
}

android {
    namespace = "com.example.medscan_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.medscan_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "medscan_dev_gemini_key", localGeminiKey)
        resValue("string", "medscan_dev_mapbox_token", localMapboxToken)
    }

    buildTypes {
        release {
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
