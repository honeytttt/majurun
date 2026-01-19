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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
subprojects {
    project.plugins.withType<com.android.build.gradle.LibraryPlugin> {
        project.extensions.configure<com.android.build.gradle.LibraryExtension> {
            if (project.name == "twitter_login") {
                namespace = "com.maru.twitter_login"
            }
        }

        // This block finds the Manifest file and removes the old 'package' attribute
        project.tasks.withType<com.android.build.gradle.tasks.ProcessLibraryManifest> {
            doFirst {
                val manifestFile = mainManifest.get().asFile
                if (manifestFile.exists()) {
                    val content = manifestFile.readText()
                    if (content.contains("package=\"com.maru.twitter_login\"")) {
                        val updatedContent = content.replace("package=\"com.maru.twitter_login\"", "")
                        manifestFile.writeText(updatedContent)
                        println("Successfully stripped forbidden package attribute from twitter_login Manifest")
                    }
                }
            }
        }
    }
}