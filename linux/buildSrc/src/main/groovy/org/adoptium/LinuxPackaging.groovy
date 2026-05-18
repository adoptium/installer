package org.adoptium

import org.gradle.api.JavaVersion
import org.gradle.api.Project
import org.gradle.api.tasks.testing.Test

/**
 * Shared build logic for Linux packaging subprojects.
 *
 * Eliminates duplication across jdk/jre × alpine/debian/redhat/suse build files
 * by extracting common Gradle configuration and parameterised task creation.
 *
 * Usage in a leaf build.gradle:
 * <pre>
 *   import org.adoptium.LinuxPackaging
 *
 *   LinuxPackaging.configure(project, [
 *       imageType : 'jdk',
 *       distro    : 'Alpine',
 *       gpgBuild  : true,
 *       gpgCheck  : true,
 *   ])
 * </pre>
 */
class LinuxPackaging {

	private static final String JUNIT_VERSION = '6.0.3'
	private static final String TESTCONTAINERS_VERSION = '1.21.4'
	private static final String ASSERTJ_VERSION = '3.27.7'

	/**
	 * Applies common configuration and creates packaging + check tasks.
	 *
	 * @param project the Gradle sub-project
	 * @param config  a map with the following keys (all optional except imageType and distro):
	 *   <ul>
	 *     <li><b>imageType</b>  – {@code 'jdk'} or {@code 'jre'} (required)</li>
	 *     <li><b>distro</b>     – display name used in task names, e.g. {@code 'Alpine'}, {@code 'Debian'}, {@code 'RedHat'}, {@code 'Suse'} (required)</li>
	 *     <li><b>dockerTag</b>  – docker image tag suffix; defaults to {@code distro.toLowerCase()}</li>
	 *     <li><b>gpgBuild</b>   – pass GPG secret to docker build (default {@code false})</li>
	 *     <li><b>localBuild</b> – support {@code INPUT_DIR} for local tarball builds (default {@code false})</li>
	 *     <li><b>archImages</b> – {@code Map<String,String>} of arch → docker base image override (default {@code [:]})</li>
	 *     <li><b>extraRunEnvs</b> – extra {@code -e} vars for docker run beyond {@code buildArch} (default {@code []})</li>
	 *     <li><b>microsoftPkg</b> – use {@code msopenjdk-*} package name when product is 'microsoft' (default {@code false})</li>
	 *     <li><b>gpgCheck</b>   – set {@code JDKGPG} env in check task (default {@code false})</li>
	 *     <li><b>archCheck</b>  – set {@code testArch} env in check task (default {@code false})</li>
	 *   </ul>
	 */
	static void configure(Project project, Map config) {
		applyCommonConfig(project)
		createTasks(project, config)
	}

	/**
	 * Applies only the common configuration (plugins, dependencies, source sets, etc.)
	 * without creating packaging tasks.  Useful for subprojects like ca-certificates
	 * that have custom task logic.
	 */
	static void applyCommonConfig(Project project) {
		project.with {
			plugins.apply('java')

			ext.junitVersion = JUNIT_VERSION
			ext.testcontainersVersion = TESTCONTAINERS_VERSION
			ext.assertjCoreVersion = ASSERTJ_VERSION

			repositories { mavenCentral() }

			group = 'org.adoptium'
			version = '1.0.0-SNAPSHOT'

			java {
				sourceCompatibility = JavaVersion.VERSION_17
				targetCompatibility = JavaVersion.VERSION_17
			}

			sourceSets {
				packageTest {
					compileClasspath += sourceSets.main.output
					runtimeClasspath += sourceSets.main.output
				}
			}

			configurations {
				packageTestImplementation.extendsFrom implementation
				packageTestRuntimeOnly.extendsFrom runtimeOnly
			}

			dependencies {
				packageTestImplementation "org.junit.jupiter:junit-jupiter:${JUNIT_VERSION}"
				packageTestRuntimeOnly   "org.junit.platform:junit-platform-launcher:${JUNIT_VERSION}"
				packageTestImplementation "org.testcontainers:testcontainers:${TESTCONTAINERS_VERSION}"
				packageTestImplementation "org.testcontainers:junit-jupiter:${TESTCONTAINERS_VERSION}"
				packageTestImplementation "org.assertj:assertj-core:${ASSERTJ_VERSION}"
			}

			test {
				useJUnitPlatform()
				testLogging {
					events 'passed', 'skipped', 'failed'
				}
			}
		}
	}

	// ── Property helpers (read from root project) ──────────────────────────

	private static String product(Project p) {
		p.rootProject.hasProperty('PRODUCT') ? p.rootProject.PRODUCT.toString().toLowerCase(Locale.US) : null
	}

	private static Integer productVersion(Project p) {
		p.rootProject.hasProperty('PRODUCT_VERSION') ? Integer.parseInt(p.rootProject.PRODUCT_VERSION) : null
	}

	private static String gpgKey(Project p) {
		p.rootProject.hasProperty('GPG_KEY') ? p.rootProject.GPG_KEY.toString() : null
	}

	private static String arch(Project p) {
		p.rootProject.hasProperty('ARCH') ? p.rootProject.ARCH.toString() : 'all'
	}

	private static String inputDir(Project p) {
		p.rootProject.hasProperty('INPUT_DIR') ? p.rootProject.INPUT_DIR.toString() : null
	}

	private static String localBuildStatus(Project p) {
		p.rootProject.hasProperty('INPUT_DIR') ? 'true' : 'false'
	}

	private static String containerRegistry(Project p) {
		p.rootProject.hasProperty('CONTAINER_REGISTRY') ? p.rootProject.CONTAINER_REGISTRY.toString() : ''
	}

	// ── Task creation ──────────────────────────────────────────────────────

	private static void createTasks(Project project, Map config) {
		def imageType    = config.imageType
		def distro       = config.distro
		def dockerTag    = (config.dockerTag ?: distro.toLowerCase()) as String
		def gpgBuild     = config.gpgBuild ?: false
		def localBuild   = config.localBuild ?: false
		def archImages   = config.archImages ?: [:]
		def extraRunEnvs = config.extraRunEnvs ?: []
		def microsoftPkg = config.microsoftPkg ?: false
		def gpgCheck     = config.gpgCheck ?: false
		def archCheck    = config.archCheck ?: false

		def capitalType     = imageType.capitalize()
		def packageTaskName = "package${capitalType}${distro}"
		def checkTaskName   = "check${capitalType}${distro}"
		def dockerImageTag  = "adoptium-packages-linux-jdk-${dockerTag}"

		createPackageTask(project, packageTaskName, dockerImageTag, imageType,
			gpgBuild, localBuild, archImages, extraRunEnvs)

		createCheckTask(project, checkTaskName, packageTaskName, imageType,
			microsoftPkg, gpgCheck, archCheck)

		// Wire to parent aggregation tasks
		project.parent."package${capitalType}".dependsOn(packageTaskName)
		project.parent."check${capitalType}Package".dependsOn(checkTaskName)
	}

	private static void createPackageTask(Project project, String taskName, String dockerImageTag,
			String imageType, boolean gpgBuild, boolean localBuild,
			Map archImages, List extraRunEnvs) {

		project.task(taskName) {
			dependsOn 'assemble'
			group = 'packaging'
			description = "Creates ${imageType.toUpperCase()} package."

			def outputDir = new File(project.buildDir.absolutePath, 'ospackage')
			outputs.dir(outputDir)

			def prod              = product(project)
			def prodVersion       = productVersion(project)
			def key               = gpgKey(project)
			def buildArch         = arch(project)
			def registry          = containerRegistry(project)
			def inputPath         = localBuild ? inputDir(project) : null
			def buildLocalFlag    = localBuild ? localBuildStatus(project) : null
			def execHelper        = project.objects.newInstance(ExecHelper)

			doLast {
				validateProductDir(project, prod, prodVersion)
				if (inputPath != null && !project.file(inputPath).exists()) {
					throw new IllegalArgumentException("Input directory '${inputPath}' not found")
				}

				// Copy packaging templates into build dir
				project.copy {
					from("src/main/packaging/${prod}/${prodVersion}/")
					into("${project.buildDir}/generated/packaging")
				}

				// Copy local build artefacts when building from a local directory
				if (localBuild && buildLocalFlag == 'true') {
					copyLocalArtefacts(project, inputPath, "${project.buildDir}/${imageType}")
				}

				// Build the Docker image
				def buildCmd = buildDockerCommand(
					dockerImageTag, buildArch, registry, key,
					gpgBuild, archImages,
					project.projectDir.absolutePath + '/src/main/packaging'
				)
				execHelper.exec {
					workingDir 'src/main/packaging'
					commandLine buildCmd
				}

				// Run the Docker container to produce packages
				def runCmd = buildDockerRunCommand(
					dockerImageTag, buildArch, prodVersion, buildLocalFlag,
					extraRunEnvs, project.buildDir, outputDir
				)
				execHelper.exec {
					workingDir project.rootDir
					commandLine runCmd
				}
			}
		}
	}

	private static void createCheckTask(Project project, String taskName, String packageTaskName,
			String imageType, boolean microsoftPkg,
			boolean gpgCheck, boolean archCheck) {

		project.task(taskName, type: Test) {
			dependsOn packageTaskName
			description = "Tests the generated packages."
			group = 'verification'

			testClassesDirs = project.sourceSets.packageTest.output.classesDirs
			classpath = project.sourceSets.packageTest.runtimeClasspath

			def prod        = product(project)
			def prodVersion = productVersion(project)
			def key         = gpgKey(project)
			def buildArch   = arch(project)
			def registry    = containerRegistry(project)

			if (microsoftPkg && prod == 'microsoft') {
				environment 'PACKAGE', "msopenjdk-${prodVersion}"
			} else {
				environment 'PACKAGE', "${prod}-${prodVersion}-${imageType}"
			}

			if (gpgCheck && key != null) {
				environment 'JDKGPG', key
			}

			if (archCheck) {
				environment 'testArch', buildArch
			}

			if (registry != null && registry != '') {
				environment 'containerRegistry', registry
			}

			useJUnitPlatform()
			testLogging {
				events 'passed', 'skipped', 'failed'
			}

			doFirst {
				validateProductDir(project, prod, prodVersion)
			}
		}
	}

	// ── Helpers ────────────────────────────────────────────────────────────

	private static void validateProductDir(Project project, String prod, Integer prodVersion) {
		if (!project.file("src/main/packaging/${prod}/${prodVersion}").exists()) {
			throw new IllegalArgumentException("Unknown product ${prod}/${prodVersion}")
		}
	}

	private static void copyLocalArtefacts(Project project, String inputPath, String targetDir) {
		project.copy {
			from(inputPath)
			into(targetDir)
			include('*.tar.gz')
		}
		project.copy {
			from(inputPath)
			into(targetDir)
			include('*.sha256*.txt')
		}
	}

	/**
	 * Builds the {@code docker build} command list.
	 */
	private static List<String> buildDockerCommand(String imageTag, String buildArch, String registry,
			String gpgKey, boolean gpgBuild,
			Map archImages, String contextPath) {
		def cmd = ['docker', 'build', '--no-cache', '--pull']

		def archImage = archImages[buildArch]
		if (archImage) {
			cmd += ['--build-arg', "IMAGE=${archImage}"]
		}

		cmd += ['-t', imageTag]

		if (gpgBuild && gpgKey) {
			cmd += ['--secret', "id=gpg,src=${gpgKey}"]
		}

		cmd += ["--build-arg=CONTAINER_REGISTRY=${registry}", '-f', 'Dockerfile', contextPath]
		return cmd
	}

	/**
	 * Builds the {@code docker run} command list.
	 */
	private static List<String> buildDockerRunCommand(String imageTag, String buildArch,
			Integer prodVersion, String buildLocalFlag,
			List extraEnvs, File buildDir, File outputDir) {
		def cmd = ['docker', 'run', '--rm', '-e', "buildArch=${buildArch}"]

		extraEnvs.each { envVar ->
			switch (envVar) {
				case 'buildVersion':
					cmd += ['-e', "buildVersion=${prodVersion}"]
					break
				case 'buildLocalFlag':
					cmd += ['-e', "buildLocalFlag=${buildLocalFlag}"]
					break
			}
		}

		cmd += [
			'--mount', "type=bind,source=${buildDir},target=/home/builder/build",
			'--mount', "type=bind,source=${outputDir.absolutePath},target=/home/builder/out",
			"${imageTag}:latest"
		]
		return cmd
	}
}
