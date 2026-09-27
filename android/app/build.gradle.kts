plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.onebit.onebit"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.onebit.onebit"
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
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

// ── Versioned artifact copies ──────────────────────────────────────────
//
// `flutter build apk` always writes `app-<mode>.apk`, and the Flutter
// Gradle plugin looks for exactly that name when copying into
// flutter-apk/ — so the originals are left untouched. Each build drops an
// extra copy that carries the version name and build number declared in
// pubspec.yaml:
//
//     OneBit-1.0.0+1-release.apk
//
// That keeps the file on disk self-describing once it leaves the repo.
fun attachVersionedApkCopy(taskName: String, mode: String) {
    tasks.matching { it.name == taskName }.configureEach {
        doLast {
            val apkDirectory = layout.buildDirectory.dir("outputs/apk/$mode").get().asFile
            val source = File(apkDirectory, "app-$mode.apk")
            if (!source.exists()) return@doLast

            val fileName = "OneBit-${flutter.versionName}+${flutter.versionCode}-$mode.apk"
            val destinations = listOf(
                apkDirectory,
                layout.buildDirectory.dir("outputs/flutter-apk").get().asFile,
            )
            destinations.forEach { directory ->
                directory.mkdirs()
                source.copyTo(File(directory, fileName), overwrite = true)
            }
            logger.lifecycle("Versioned APK: $fileName")
        }
    }
}

attachVersionedApkCopy("assembleDebug", "debug")
attachVersionedApkCopy("assembleRelease", "release")

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    testImplementation("junit:junit:4.13.2")
}
