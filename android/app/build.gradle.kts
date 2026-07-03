plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.iconvert.iconvert"
    compileSdk = 35
    // 不指定 ndkVersion，避免 Gradle 下载 2GB NDK
    // 我们项目用纯 Dart，没有 C++ 代码，不需要 NDK

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.iconvert.iconvert"
        // iConvert 项目要求：Android 5.0+ 起步
        minSdk = flutter.minSdkVersion
        targetSdk = 33
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 不声明 abiFilters，避免 AGP 触发 NDK 安装
        // FFmpeg 自带 3 个 ABI 的 .so，会自动按设备选择
    }

    buildTypes {
        release {
            // 侧载分发用 debug 签名
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            // 关键：彻底跳过 lint（lint 中间产物占用大量磁盘）
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 彻底禁用 lint
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
