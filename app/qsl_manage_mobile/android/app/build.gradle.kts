plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.jinyao.moe.qsl_manage_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.jinyao.moe.qsl_manage_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 签名配置，这里请更换成自己的签名配置文件
    val localProperties = File(rootProject.projectDir, "key.properties")
    val properties = Properties().apply {
        if (localProperties.exists()) {
            load(localProperties.inputStream())
        }
    }
    val keyPath = properties.getProperty("storeFile") ?: error("keyPath not found")
    val signingStorePassword = properties.getProperty("storePassword") ?: error("storePassword not found")
    val signingKeyAlias = properties.getProperty("keyAlias") ?: error("keyAlias not found")
    val signingKeyPassword = properties.getProperty("keyPassword") ?: error("keyPassword not found")
    signingConfigs {
        create("release") {
            storeFile = file(keyPath)
            storeType = if (keyPath.endsWith(".p12", ignoreCase = true)) "PKCS12" else "JKS"
            this.storePassword = signingStorePassword
            this.keyAlias = signingKeyAlias
            this.keyPassword = signingKeyPassword
            enableV1Signing = true // 兼容 Android 7.0 以下
            enableV2Signing = true // 强制启用 V2 签名（Android 7.0+ ，更安全）
        }
    }



    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true // 启用代码混淆
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
