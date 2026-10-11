import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val propertiesFile = rootProject.file("local.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use { stream -> load(stream) }
    }
}

fun localBuildConfigValue(name: String): String =
    localProperties.getProperty(name, "")
        .replace("\\", "\\\\")
        .replace("\"", "\\\"")

android {
    namespace = "br.gov.itapema.cami"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "br.gov.itapema.cami"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // O gravador RTSP nativo exige Android 7.0 (API 24) ou superior.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // These values are deliberately read from android/local.properties,
        // which is ignored by Git. They are only for the local IKEv2 test APK.
        buildConfigField(
            "String",
            "CAMI_VPN_SERVER",
            "\"${localBuildConfigValue("CAMI_VPN_SERVER")}\"",
        )
        buildConfigField(
            "String",
            "CAMI_VPN_REMOTE_ID",
            "\"${localBuildConfigValue("CAMI_VPN_REMOTE_ID")}\"",
        )
        buildConfigField(
            "String",
            "CAMI_VPN_PSK",
            "\"${localBuildConfigValue("CAMI_VPN_PSK")}\"",
        )
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
