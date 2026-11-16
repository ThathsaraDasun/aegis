plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

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
    // Android test configuration requires source and build paths on the same drive.
    // Flutter's Pub cache may be on a different Windows drive from this project.
    val newSubprojectBuildDir: Directory =
        if (project.projectDir.toPath().root == newBuildDir.asFile.toPath().root) {
            newBuildDir.dir(project.name)
        } else {
            project.layout.projectDirectory.dir("build")
        }
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = "17"
        targetCompatibility = "17"
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        // Kotlin incremental caches also resolve plugin sources against the root project.
        if (project.projectDir.toPath().root != rootProject.projectDir.toPath().root) {
            incremental = false
        }
        kotlinOptions {
            jvmTarget = "17"
        }
        compilerOptions {
            freeCompilerArgs.add("-Xskip-metadata-version-check")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    delete(subprojects.map { it.layout.buildDirectory })
}
