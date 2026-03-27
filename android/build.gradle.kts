import com.android.build.gradle.LibraryExtension
import org.gradle.api.file.Directory
import org.gradle.api.tasks.Delete

plugins {}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// structură custom de build dir (poți lăsa dacă o folosești)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects { project.evaluationDependsOn(":app") }

// ✅ fixează namespace + compileSdk pentru ar_flutter_plugin fără afterEvaluate
subprojects {
    plugins.withId("com.android.library") {
        if (name.contains("ar_flutter_plugin")) {
            extensions.configure<LibraryExtension>("android") {
                namespace = "io.carius.lars.ar_flutter_plugin"
                compileSdk = 34
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}