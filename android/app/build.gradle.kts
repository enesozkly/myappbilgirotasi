import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Keystore (Anahtar) ayarlarını güvenli bir şekilde yüklüyoruz
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sonerlerbilisim.bilgirotasi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    signingConfigs {
        create("release") {
            // key.properties dosyasından verileri çekiyoruz
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storePassword = keystoreProperties.getProperty("storePassword")
            
            val path = keystoreProperties.getProperty("storeFile")
            if (path != null) {
                storeFile = file(path)
            }
        }
    }

    defaultConfig {
        applicationId = "com.sonerlerbilisim.bilgirotasi"
        
        // Firebase ve Reklam paketleri için minimum 23 şartı
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Uygulamayı Play Store için gerçek anahtarınla imzalıyoruz
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// KRİTİK DÜZELTME: Eski 'kotlinOptions' yerine yeni 'compilerOptions' DSL kullanımı
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
    compilerOptions {
        // Tüm Kotlin derleme görevlerini Java ile uyumlu olması için 17 sürümüne sabitliyoruz
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    
}