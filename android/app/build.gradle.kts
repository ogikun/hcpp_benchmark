plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.example.hcpp_benchmark"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.example.hcpp_benchmark"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 同じ端末に「従来方式」と「HCPP」の 2 つをインストールして比較するためのフレーバー
    flavorDimensions += "composition"
    productFlavors {
        create("legacy") {
            dimension = "composition"
            applicationIdSuffix = ".legacy"
            resValue("string", "app_name", "PV Bench (legacy)")
            manifestPlaceholders["enableHcpp"] = "false"
        }
        create("hcpp") {
            dimension = "composition"
            applicationIdSuffix = ".hcpp"
            resValue("string", "app_name", "PV Bench (HCPP)")
            manifestPlaceholders["enableHcpp"] = "true"
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

flutter {
    source = "../.."
}
