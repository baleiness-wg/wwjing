import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.baleine.wwjing.bookmark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.baleine.wwjing.bookmark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildFeatures {
        resValues = true
    }

    flavorDimensions += "appType"
    productFlavors {
        create("kitchen") {
            dimension = "appType"
            applicationIdSuffix = ".kitchen"
            resValue("string", "app_name", "微微鲸厨房")
        }
        create("star") {
            dimension = "appType"
            applicationIdSuffix = ".star"
            resValue("string", "app_name", "微微鲸星标")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

val appType = providers.gradleProperty("dart-defines").orNull
    ?.split(",")
    ?.mapNotNull { encoded ->
        runCatching { String(Base64.getDecoder().decode(encoded)) }.getOrNull()
    }
    ?.firstOrNull { it.startsWith("APP_TYPE=") }
    ?.substringAfter("=")

gradle.taskGraph.whenReady {
    val selectedFlavors = allTasks
        .map { it.name.lowercase() }
        .mapNotNull { name ->
            when {
                "kitchen" in name -> "kitchen"
                "star" in name -> "star"
                else -> null
            }
        }
        .toSet()
    if (selectedFlavors.isNotEmpty() && (appType == null || appType !in selectedFlavors)) {
        throw GradleException(
            "APP_TYPE 必须与 Flutter flavor 匹配：当前 flavor=${selectedFlavors.joinToString()}，APP_TYPE=${appType ?: "未提供"}"
        )
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
