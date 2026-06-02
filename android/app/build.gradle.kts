plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Load keystore properties from android/key.properties
val keystoreProps = mutableMapOf<String, String>()
val keystorePropsFile = rootProject.file("key.properties")
if (keystorePropsFile.exists()) {
    keystorePropsFile.readLines().forEach { line ->
        val trimmed = line.trim()
        if (trimmed.isNotEmpty() && !trimmed.startsWith("#")) {
            val idx = trimmed.indexOf("=")
            if (idx > 0) {
                keystoreProps[trimmed.substring(0, idx).trim()] =
                    trimmed.substring(idx + 1).trim()
            }
        }
    }
}

android {
    namespace = "com.vkulakra.movo"
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
        applicationId = "com.vkulakra.movo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // ── Release signing ──────────────────────────────────────────────
    signingConfigs {
        create("release") {
            storeFile = rootProject.file(keystoreProps["storeFile"] ?: "")
            storePassword = keystoreProps["storePassword"] ?: ""
            keyAlias = keystoreProps["keyAlias"] ?: ""
            keyPassword = keystoreProps["keyPassword"] ?: ""
        }
    }

    buildTypes {
        release {
            // Enable R8 code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )

            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
