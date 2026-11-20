import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

dependencies {
    implementation("androidx.media:media:1.7.0")
}

android {
    namespace = "com.meidlinger.lain"
    compileSdk = 37
    // The SDK ships platform 37 as `android-37.0`; without this AGP looks the
    // hash string up as plain `android-37` and fails to resolve the platform.
    // See BUILDING.md 6.5 - this is a local compatibility patch.
    compileSdkMinor = 0
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    defaultConfig {
        applicationId = "com.meidlinger.lain"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            applicationIdSuffix = ".debug" 
        }
    }

    configurations.all {
        resolutionStrategy {
            force("androidx.appcompat:appcompat:1.6.1")
            force("androidx.fragment:fragment:1.6.2")
        }
    }

}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

// Flutter names the split artifacts after the Gradle module (`app-...`). The
// release is published as Lain, so give the APK the same name here instead of
// requiring a manual rename after every build. Keep the ABI in the name: the
// arm64 split is the only one distributed.
androidComponents {
    onVariants(selector().all()) { variant ->
        variant.outputs.forEach { output ->
            val abi = output.filters.firstOrNull {
                it.filterType ==
                    com.android.build.api.variant.FilterConfiguration.FilterType.ABI
            }?.identifier
            val name = buildString {
                append("lain-")
                if (abi != null) {
                    append(abi)
                    append("-")
                }
                append(variant.name)
                append(".apk")
            }
            val implementation =
                output as? com.android.build.api.variant.impl.VariantOutputImpl
            implementation?.outputFileName?.set(name)
        }
    }
}

// The Flutter tool copies the Gradle APK into `outputs/flutter-apk` under the
// module name. Keep the Lain-named copy there as well, so the path documented
// in BUILDING.md is the one that actually exists after `flutter build apk`.
tasks.matching { it.name == "assembleRelease" }.configureEach {
    doLast {
        val buildDir = project.layout.buildDirectory.get().asFile
        val releaseDir = File(buildDir, "outputs/apk/release")
        val apkDir = File(buildDir, "outputs/flutter-apk")
        apkDir.mkdirs()
        releaseDir.listFiles { file ->
            file.isFile && file.name.startsWith("lain-") && file.name.endsWith(".apk")
        }?.forEach { source ->
            source.copyTo(File(apkDir, source.name), overwrite = true)
        }
    }
}
