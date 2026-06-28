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

// Alguns plugins (ex.: receive_sharing_intent) declaram compileSdk 37, mas o
// pacote estavel android-37 ainda nao existe no repositorio. Forca esses
// subprojetos a compilar contra a 36 (instalada). Usa reflection para evitar
// depender de imports do AGP no script raiz.
subprojects {
    // Pula o :app (ja avaliado por evaluationDependsOn acima e ja em compileSdk 36).
    if (project.name != "app") {
        afterEvaluate {
            val androidExt = extensions.findByName("android") ?: return@afterEvaluate
            runCatching {
                val current = androidExt.javaClass.getMethod("getCompileSdkVersion")
                    .invoke(androidExt) as? String
                val api = current?.removePrefix("android-")?.substringBefore(".")?.toIntOrNull()
                if (api == null || api > 36) {
                    androidExt.javaClass
                        .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        .invoke(androidExt, 36)
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
