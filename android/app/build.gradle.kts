import java.util.Properties

// Google Maps key: android/secrets.properties (git-ignored) → local.properties → placeholder.
val mapsApiKey: String = run {
    val props = Properties()
    listOf("secrets.defaults.properties", "local.properties", "secrets.properties")
        .map { rootProject.file(it) }
        .filter { it.exists() }
        .forEach { file -> file.inputStream().use { props.load(it) } }
    props.getProperty("MAPS_API_KEY") ?: "YOUR_MAPS_API_KEY_HERE"
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aegis.safewalk"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.aegis.safewalk"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    dependencies {
        implementation("com.google.firebase:firebase-auth:23.2.1")
        implementation("com.google.firebase:firebase-firestore:25.1.4")
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.2")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
