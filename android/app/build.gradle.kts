import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.alper.rutin"
    // compileSdk = DERLEME zamanında hangi API'lerin görünür olduğunu belirler;
    // uygulamanın çalışma davranışını (targetSdk) veya desteklenen en düşük
    // cihazı (minSdk) DEĞİŞTİRMEZ. google_mobile_ads, in_app_purchase_android,
    // sentry_flutter vb. bağımlılıklar AAR metadata'da compileSdk >= 36
    // istediği için 36'ya çekildi. targetSdk hâlâ 35 (Google Play 2025+ zorunlu).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.alper.rutin"
        // Flutter'ın varsayılanı kullanılıyor; bu sürümde 24 (derlenmiş
        // APK'da doğrulandı: `aapt2 dump badging` → minSdkVersion:'24').
        // google_mobile_ads 9.x en az API 23, flutter_local_notifications 21+
        // en az API 24 istiyor — ikisi de karşılanıyor.
        minSdk = flutter.minSdkVersion
        // Google Play zorunluluğu: 31 Ağustos 2026'dan itibaren yeni uygulama
        // ve güncellemeler Android 16'yı (API 36) hedeflemek zorunda. compileSdk
        // zaten 36 olduğu için bu değişiklik düşük riskli.
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // AdMob Uygulama Kimliği (com.google.android.gms.ads.APPLICATION_ID).
        // Gerçek admob.google.com kimliğinizi vermek için:
        //   flutter build apk -PADMOB_APP_ID=ca-app-pub-XXXX~YYYY
        // veya android/gradle.properties içine `ADMOB_APP_ID=ca-app-pub-XXXX~YYYY`
        // ekleyin. Verilmezse Google'ın TEST kimliğine düşer (mağazaya bu
        // haliyle gönderilmemeli).
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("ADMOB_APP_ID") as String?)
                ?: System.getenv("ADMOB_APP_ID")
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("release")
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
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
