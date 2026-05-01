import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.majurun.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.majurun.app"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Only include ARM architectures (excludes x86 emulator-only libs)
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }

        // Load API keys from local.properties (not committed to Git)
        val localPropertiesFile = rootProject.file("local.properties")
        val localProperties = Properties()
        if (localPropertiesFile.exists()) {
            localProperties.load(localPropertiesFile.inputStream())
        }

        // Google Maps API Key — env var takes priority (used by CI),
        // falls back to local.properties (used for local dev)
        val mapsApiKey = System.getenv("MAPS_API_KEY")
            ?: localProperties.getProperty("MAPS_API_KEY", "")
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    // Detect whether this Gradle invocation is actually building a release.
    // Used to gate the release-keystore requirement so that `assembleDebug`
    // works on developer machines that have no key.properties.
    val isReleaseBuild = gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true) ||
        it.contains("Bundle",  ignoreCase = true)
    }
    val keystorePropertiesFile = rootProject.file("key.properties")

    signingConfigs {
        // Shared debug keystore — same SHA on every machine, registered once in Firebase.
        // Committed to repo at android/debug.keystore (safe: debug only, not production).
        getByName("debug") {
            storeFile = rootProject.file("debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // Release signing config — loaded from key.properties (not committed).
        // Only configured when key.properties is present; the buildTypes.release
        // block below fails the build if a release task is requested without it.
        // This avoids breaking `assembleDebug` on dev machines without the key.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                val keystoreProperties = Properties()
                keystoreProperties.load(keystorePropertiesFile.inputStream())
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // FAIL CLOSED: a release task without key.properties stops the build
            // — no silent fallback to the debug keystore for production artifacts.
            if (isReleaseBuild) {
                check(keystorePropertiesFile.exists()) {
                    "key.properties not found. Release builds require a production keystore. " +
                    "Supply key.properties or run a debug build instead."
                }
                signingConfig = signingConfigs.getByName("release")
            }

            // Enable ProGuard/R8 for release builds
            isMinifyEnabled = true
            isShrinkResources = true
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
    // Core library desugaring for Java 8+ APIs on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Wear OS support for smartwatch connectivity
    implementation("com.google.android.gms:play-services-wearable:18.1.0")
}
