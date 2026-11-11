allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Optional, for a Windows machine whose antivirus (360, Defender, ...) locks the
// files the C++ metadata step writes into the project build directory: run the
// build with -PjniBuildDir=<a path on another drive> and only the jni module's
// intermediates move there. Set it in ~/.gradle/gradle.properties as
// `org.gradle.project.jniBuildDir=C:/jni-build` so `flutter build` picks it up.
// See BUILDING.md.
subprojects {
    val jniBuildDir = providers.gradleProperty("jniBuildDir").orNull
    if (project.name == "jni" && !jniBuildDir.isNullOrBlank()) {
        project.layout.buildDirectory.value(
            project.objects.directoryProperty().fileValue(File(jniBuildDir)),
        )
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
