plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.onebit.onebit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

defaultConfig {
        applicationId = "dev.onebit.onebit"
        // OneBit targets Android 10 (API 29) and newer: BLE central role,
        // scoped permissions and connected-device foreground services are
        // stable from here on. Flutter's default (24) admits devices the
        // transport does not support.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // OneBit product tiers. Flavor IDs cannot collide with AGP build-type
    // names ("debug"/"release" are reserved), so the tiers are `dev`, `beta`
    // and `prod`; Dart maps them (via --dart-define=FLAVOR) to the semantic
    // flavors debug/beta/release. Each tier gets its own applicationId so
    // the three products can coexist on one device.
    flavorDimensions += "tier"

    productFlavors {
        create("dev") {
            dimension = "tier"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["onBitFlavorLabel"] = "OneBit Dev"
        }
        create("beta") {
            dimension = "tier"
            applicationIdSuffix = ".beta"
            versionNameSuffix = "-beta"
            manifestPlaceholders["onBitFlavorLabel"] = "OneBit Beta"
        }
        create("prod") {
            dimension = "tier"
            applicationIdSuffix = ""
            manifestPlaceholders["onBitFlavorLabel"] = "OneBit"
        }
    }

    buildTypes {
        release {
            // Signing with the debug keys for now; swap for the store keystore
            // (managed by CI) before shipping builds.
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
    target = "lib/main.dart"
}

dependencies {
    // Runtime permissions + modern receiver registration for the BLE
    // transport (ActivityCompat, ContextCompat).
    implementation("androidx.core:core-ktx:1.13.1")
    testImplementation("junit:junit:4.13.2")
}