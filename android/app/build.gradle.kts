plugins {
    id("com.android.application")
    id("com.google.gms.google-services")   // doar dacă folosești Firebase
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // trebuie să fie după Android + Kotlin
}

android {
    namespace = "com.example.itec"   // pune pachetul tău
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
        applicationId = "com.example.itec"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // semnare debug temporar; înlocuiește cu semnarea ta de release când vrei
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}