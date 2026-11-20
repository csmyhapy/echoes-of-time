plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlin.plugin.serialization")
    id("com.google.devtools.ksp")
}

android {
    namespace = "life.lifememory.echosoftime"
    compileSdk = 35

    defaultConfig {
        applicationId = "life.lifememory.echosoftime"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        resourceConfigurations += listOf("en", "zh-rCN", "es", "fr", "de", "it", "nl", "pt-rBR", "ja", "ko")
    }

    signingConfigs {
        create("releaseConfig") {
            // 正式发布前替换为你的 keystore；缺失时 release 走 debug 签名以便自测
            val ksPath = System.getenv("ECHO_KEYSTORE") ?: rootProject.file("keystore/echo-release.jks").absolutePath
            val ksFile = file(ksPath)
            if (ksFile.exists()) {
                storeFile = ksFile
                storePassword = System.getenv("ECHO_STORE_PASSWORD") ?: ""
                keyAlias = System.getenv("ECHO_KEY_ALIAS") ?: "echo"
                keyPassword = System.getenv("ECHO_KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        debug {
            // 开发期直接解锁完整功能，与 iOS Debug 包行为一致
            buildConfigField("boolean", "FORCE_PRO", "true")
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
        release {
            buildConfigField("boolean", "FORCE_PRO", "false")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            val ks = signingConfigs.getByName("releaseConfig")
            if (ks.storeFile?.exists() == true) signingConfig = ks
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }
}

ksp {
    arg("room.schemaLocation", "$projectDir/schemas")
}

dependencies {
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("androidx.appcompat:appcompat:1.7.0")

    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")

    implementation("androidx.navigation:navigation-compose:2.8.3")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.8.6")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.6")

    implementation("androidx.room:room-runtime:2.6.1")
    implementation("androidx.room:room-ktx:2.6.1")
    ksp("androidx.room:room-compiler:2.6.1")

    implementation("io.coil-kt:coil-compose:2.7.0")

    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.documentfile:documentfile:1.0.1")

    implementation("com.android.billingclient:billing-ktx:7.1.1")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
}
