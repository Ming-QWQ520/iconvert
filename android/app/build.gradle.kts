plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.iconvert.iconvert"
    // 提升到 36：file_picker / flutter_plugin_android_lifecycle / shared_preferences_android 要求
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.iconvert.iconvert"
        // iConvert 项目要求：Android 5.0+ 起步
        minSdk = 21
        targetSdk = 33
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 侧载分发用 debug 签名
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 彻底禁用 lint（避免 lint 中间产物占用磁盘）
    lint {
        abortOnError = false
        checkReleaseBuilds = false
        checkAllWarnings = false
        ignoreWarnings = true
        quiet = true
        disable += setOf("all")
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
