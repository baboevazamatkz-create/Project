import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing lives in android/key.properties, which is never committed;
// CI writes it from repository secrets before building. Without that file --
// a plain local build, or a checkout with no access to the secrets -- the
// release build falls back to the debug key so it still compiles.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

android {
    namespace = "com.baboevazamatkz.expense_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent. Google Play keys every installed copy of the app on
        // this string and will not let it change after the first upload:
        // a different id is a different app, with its own listing, its own
        // reviews and no way to update anyone who installed the old one.
        applicationId = "com.baboevazamatkz.expense_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml unless CI passes --build-number, which it does:
        // Play refuses an upload whose version code is not higher than every
        // code uploaded before, and a number tied to the build is the one
        // thing that always rises.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // A stable key matters for more than trust signals: Android
            // refuses to install an update signed by a different key, and the
            // debug keystore is generated fresh on every clean CI runner --
            // so every build used to need an uninstall first.
            signingConfig =
                signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")

            // The Dart half of the app is compiled ahead of time and is not
            // touched by any of this. The Java and Kotlin half is: the
            // Firestore and Auth SDKs the home-screen widget needs are large,
            // and without R8 every class in them ships whether or not
            // anything calls it.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // One .aab carries every architecture and Play hands each phone only the
    // slice it can run, which is most of why the download is a third of the
    // universal APK. Naming the dimensions explicitly rather than relying on
    // the defaults, since the download size depends on them.
    bundle {
        abi { enableSplit = true }
        density { enableSplit = true }
        language {
            // Off on purpose. Play would otherwise deliver only the system
            // language's resources, and the app is Russian on a phone set to
            // any language -- a Kazakh or English phone would come up with
            // strings missing.
            enableSplit = false
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
    // The widget records straight into Firestore from its own broadcast
    // receiver, so the app module needs the native SDKs on its compile
    // classpath -- the Flutter plugins pull them in transitively, but a
    // plugin's transitive dependencies are not visible to app code. The
    // BoM keeps the two in step; it is the generation cloud_firestore 5.6
    // and firebase_auth 5.7 are built against.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-auth")
}
