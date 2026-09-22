plugins { id("com.android.application"); id("com.google.gms.google-services"); id("dev.flutter.flutter-gradle-plugin") }
val lvlloKeystorePath = System.getenv("LVLLOOL_KEYSTORE_PATH")
val lvlloKeystorePassword = System.getenv("LVLLOOL_KEYSTORE_PASSWORD")
val lvlloKeyPassword = System.getenv("LVLLOOL_KEY_PASSWORD")
val hasLvlloReleaseSigning = !lvlloKeystorePath.isNullOrBlank() && !lvlloKeystorePassword.isNullOrBlank() && !lvlloKeyPassword.isNullOrBlank() && file(lvlloKeystorePath!!).exists()

android { namespace = "com.lvlool.game"; compileSdk = flutter.compileSdkVersion; ndkVersion = flutter.ndkVersion
compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
defaultConfig { applicationId = "com.app.mmxx"; minSdk = flutter.minSdkVersion; targetSdk = flutter.targetSdkVersion; versionCode = flutter.versionCode; versionName = flutter.versionName }
buildTypes { getByName("debug") { signingConfig = signingConfigs.getByName("debug") }; release { if (hasLvlloReleaseSigning) { signingConfig = signingConfigs.create("lvlloRelease").apply { storeFile = file(lvlloKeystorePath!!); storePassword = lvlloKeystorePassword; keyAlias = "lvllo_release"; keyPassword = lvlloKeyPassword } } else { signingConfig = signingConfigs.getByName("debug") } } } }
kotlin { compilerOptions { jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17 } }
flutter { source = "../.." }
