/* Used By Jenkins Job sfr-build-linux-package-modular */

/* Constant Declarations */

def NODE_LABEL = 'build&&linux&&x64&&dockerBuild&&dynamicAzure' // Default node
def PRODUCT = 'temurin'
def JVM = 'hotspot'
def baseURL = "https://github.com/adoptium/"
def binaryRepo = "${params.Version.replace('jdk', 'temurin')}-binaries/releases/tag/${params.Tag}"
def binaryDLRepo = "${params.Version.replace('jdk', 'temurin')}-binaries/releases/download/${params.Tag}"
def fullURL = "${baseURL}/${binaryRepo}"
def dlURL = "${baseURL}/${binaryDLRepo}"
def PKGBUILDLABEL=""

// Global Variables
def DLfilenames = []
def JDKArray = []
def ModifiedJDKArray = []
def DISTS_TO_BUILD = []
def distro = ""
def arch = ""
def ReleaseVersion = ""
def Release = ""
def Version = ""
def Build = ""
def packagearch = ""
def packagearchDeb = ""
def packagearchRhel = ""
def PackageReleaseVersion = "0"
def upstreamversion = ""
def upstreamversionARM32 = ""
/* Have Some Default Node Labels */
def PKGBUILDLABELAPK = 'build&&linux&&x64&&dockerBuild&&dynamicAzure'
def PKGBUILDLABELDEB = 'build&&linux&&x64&&dockerBuild&&dynamicAzure'
def PKGBUILDLABELRHEL = 'build&&linux&&x64&&dockerBuild&&dynamicAzure'

// Function Definitions Begin

// Helper function to download and validate files
def validateAndDownloadArtifact(url, file) {
    echo "Downloading: ${url}"
    def result = sh(script: "curl -sSL -O ${url}", returnStatus: true)
    if (result != 0) {
        error("Failed to download ${file}. File not found or an error occurred.")
    }
    echo "Downloaded: ${file}"
}

// Helper function to validate checksum
def validateChecksum(file, checksumFile) {
    def expectedChecksum = sh(script: "awk '{print \$1}' ${checksumFile}", returnStdout: true).trim()
    def calculatedChecksum = sh(script: "sha256sum ${file} | awk '{print \$1}'", returnStdout: true).trim()
    if (expectedChecksum != calculatedChecksum) {
        error("Checksum mismatch for ${file}. Expected: ${expectedChecksum}, but found: ${calculatedChecksum}.")
    }
    echo "Checksum validation successful for ${file}."
    return calculatedChecksum
}

// Helper function to extract upstream version from tar file
def extractUpstreamVersionFromTar(file) {
    def version = sh(script: "tar xvfz \"${file}\" | head -n 1 | cut -d/ -f1", returnStdout: true).trim()
    sh "rm -rf \"${version}\""
    echo "Extracted upstream version: ${version}"
    return version
}

// Helper function to cleanup files
def cleanupFiles(files) {
    files.each { file ->
        sh "rm -rf ${file}"
    }
}

// Helper function to Set Labels
def getPackageBuildLabel(String arch, String distro) {
    switch (distro) {
        case 'APK':
            return (arch == 'x64') ? 'build&&linux&&x64&&dockerBuild&&dynamicAzure' :
                   (arch == 'aarch64') ? 'docker&&linux&&aarch64' :
                   'build&&linux&&x64&&dockerBuild&&dynamicAzure'

        case 'DEB':
            return (arch == 'x64') ? 'build&&linux&&x64&&dockerBuild&&dynamicAzure' :
                   (arch == 'arm') ? 'docker&&linux&&aarch64' :
                   (arch == 'aarch64') ? 'docker&&linux&&aarch64' :
                   (arch == 'ppc64le') ? 'build&&docker&&ppc64le' :
                   (arch == 's390x') ? 'docker&&s390x&&dockerBuild' :
                   (arch == 'riscv64') ? 'dockerbuild&&linux&&riscv64' :
                   'build&&linux&&x64&&dockerBuild&&dynamicAzure'

        case 'RHEL':
            return 'build&&linux&&x64&&dockerBuild&&dynamicAzure'

        default:
            error("Unsupported distro: ${distro}")
    }
}
// Function Definitions End


/* Pipeline Declaration */
pipeline {
    agent none  // No Default Agent
    options {
        timeout(time: 2, unit: 'HOURS')
    }

      parameters {
          string(name: 'Tag', defaultValue: 'jdk-23+37', description: 'Release Tag')
          string(name: 'Version', defaultValue: 'jdk23', description: 'Release Version')
          string(name: 'Artifacts_To_Copy', defaultValue: '**/alpine-linux/aarch64/temurin/*.tar.gz,**/alpine-linux/aarch64/temurin/*.zip,**/alpine-linux/aarch64/temurin/*.sha256.txt,**/alpine-linux/aarch64/temurin/*.msi,**/alpine-linux/aarch64/temurin/*.pkg,**/alpine-linux/aarch64/temurin/*.json,**/alpine-linux/aarch64/temurin/*.sig', description: 'Artifacts String')
          booleanParam(name: 'Release', defaultValue: false, description: 'Release Flag' )
          booleanParam(name: 'Dry_Run', defaultValue: false, description: 'Release Dry Run')
          booleanParam(name: 'enableGpgSigning', defaultValue: true, description: 'Require GPG Signing')
          booleanParam(name: 'enableDebug', defaultValue: false, description: 'Tick to enable --stacktrace for gradle build')
          booleanParam(name: 'RePackage', defaultValue: false, description: 'Tick if this is a republish of an existing package, ie xx.xxx.2 , rather than the base release of a package (1)')
          string(name: 'Package_Increment', defaultValue: '1', description: 'This is the incremental number used for re-releases of package versions - Should be set appropriately if RePackage is True')
      }
// Stage Definition - Start
      stages {
// Print Parameters Stage - Start
          stage('Print Parameters') {
            agent { label NODE_LABEL }
              steps {
                  script {
                      echo "Tag : ${params.Tag}"
                      echo "Version : ${params.Version}"
                      echo "Artifacts : ${params.Artifacts_To_Copy}"
                      echo "Release : ${params.Release}"
                      echo "Dry Run : ${params.Dry_Run}"
                  }
              }
          }
// Print Parameters Stage - End
// Process Parameters Stage - Start
          stage('Process Parameters') {
            agent { label NODE_LABEL }
            when {
                expression { return params.Release }
            }
            steps {
                script{

                    // Figure Out Which Dist This Run Is For

                    if (params.Artifacts_To_Copy.contains('alpine-linux')) {
                        distro  = "alpine-linux"
                    } else if (params.Artifacts_To_Copy.contains('linux')) {
                        distro = "linux"
                    } else {
                        error("The Artifacts Are For Neither Linux OR Alpine")
                    }

                    // Figure Out Which Arch This Run Is For
                    if (params.Artifacts_To_Copy.contains('aarch64')) {
                        arch  = "aarch64"
                    } else if (params.Artifacts_To_Copy.contains('x64')) {
                        arch  = "x64"
                    } else if (params.Artifacts_To_Copy.contains('s390x')) {
                        arch  = "s390x"
                    } else if (params.Artifacts_To_Copy.contains('arm')) {
                        arch  = "arm"
                    } else if (params.Artifacts_To_Copy.contains('ppc64le')) {
                        arch  = "ppc64le"
                    } else if (params.Artifacts_To_Copy.contains('riscv64')) {
                        arch  = "riscv64"
                    } else {
                        error("The Artifacts Are For An Unsupported Architecture")
                    }

                    echo "DEBUG 00 - arch = ${arch}"

                    PKGBUILDLABELAPK = getPackageBuildLabel(arch, 'APK')
                    PKGBUILDLABELDEB = getPackageBuildLabel(arch, 'DEB')
                    PKGBUILDLABELRHEL = getPackageBuildLabel(arch, 'RHEL')

                    // // Derive The Build Arch Label For The Package Build Step
                    // // Note that Arm32 is built in a 32bit container on a 64 bit host
                    // PKGBUILDLABELAPK = (arch == 'x64') ? 'build&&linux&&x64&&dockerBuild&&dynamicAzure' :
                    //                    (arch == 'aarch64') ? 'docker&&linux&&aarch64' : 
                    //                   'build&&linux&&x64&&dockerBuild&&dynamicAzure'
                                      
                    // PKGBUILDLABELDEB = (arch == 'x64') ? 'build&&linux&&x64&&dockerBuild&&dynamicAzure' :
                    //                   (arch == 'arm') ? 'docker&&linux&&aarch64' : 
                    //                   (arch == 'aarch64') ? 'docker&&linux&&aarch64' : 
                    //                   (arch == 'ppc64le') ? 'build&&docker&&ppc64le' :
                    //                   (arch == 's390x') ? 'docker&&s390x&&dockerBuild' :
                    //                   (arch == 'riscv64') ? 'dockerbuild&&linux&&riscv64' :
                    //                   'build&&linux&&x64&&dockerBuild&&dynamicAzure'
                    
                    // PKGBUILDLABELRHEL = 'build&&linux&&x64&&dockerBuild&&dynamicAzure'

                    packagearchDeb = (arch == 'x64') ? 'amd64' :
                                     (arch == 'arm') ? 'armhf' :
                                     (arch == 'aarch64') ? 'arm64' :
                                     (arch == 'ppc64le') ? 'ppc64el' :
                                     (arch == 's390x') ? 's390x' :
                                     (arch == 'riscv64') ? 'riscv64' :
                                     'unknown'

                    // Fix Architectures To Be RHEL/Suse Control File Compatible
                    // s390x and riscv64 are OK
                    // Reqd: x64 armv7hl aarch64 ppc64le

                    packagearchRhel = (arch == 'x64') ? 'x86_64' :
                                      (arch == 'arm') ? 'armv7hl' :
                                      (arch == 'aarch64') ? 'aarch64' :
                                      (arch == 'ppc64le') ? 'ppc64le' :
                                      (arch == 's390x') ? 's390x' :
                                      (arch == 'riscv64') ? 'riscv64' :
                                      'unknown'


                    // Version Number Parsing

                    def vername = ''
                    def verversion = ''
                    def verbuild = ''

                    // Add Special Handling For JDK8 Version Number
                    // jdk8u432-b06

                    if (params.Tag?.startsWith("jdk8")) {
                        echo "JDK 8"
                        def split = (params.Tag =~ /(jdk)(\d+u\d+)-(b\d+)/)
                        if (split.find()) {
                            // println("Full Match: ${split[0][0]}")
                            vername = split[0][1]          // "jdk"
                            verversion = split[0][2]       // "8u432"
                            verbuild = split[0][3]         // "06"
                            } else {
                                 error("The version string format does not match the expected pattern.")
                        }
                    } else {
                        echo "Not JDK8"
                    // Parse The Version Tag, Into Usable Components
                    
                    def split = (params.Tag =~ /(jdk)-(\d[\d.]*)([+_]\d+)?/)

                    if (split.find()) {
                        vername = split.group(1)
                        verversion = split.group(2)
                        verbuild = split.group(3)?.replaceAll("[+_]", "")
                    } else {
                        error("The version string format does not match the expected pattern.")
                    }

                    }

                    // echo "Debug 01"
                    // echo "01 - Vername = ${vername}"
                    // echo "02 - VerVer  = ${verversion}"
                    // echo "03 - VerBLD  = ${verbuild}"

                    // Construct the Filename
                    def filennameFinal =""
                    def filenamePrefix = "Open"
                    def filenameSuffix = "tar.gz"
                    def filenameVersion = params.Version.toUpperCase() + "U"
                    def packageTypes = ['jdk', 'jre']

                    packageTypes.each { packageType ->
                      if (params.Tag?.startsWith("jdk8")) {
                        filenameFinal = "${filenamePrefix}${filenameVersion}-${packageType}_${arch}_${distro}_${JVM}_${verversion}${verbuild ?: 'N/A'}"
                        ReleaseVersion = "${verversion}${verbuild ?: 'N/A'}"
                      } else {
                        filenameFinal = "${filenamePrefix}${filenameVersion}-${packageType}_${arch}_${distro}_${JVM}_${verversion}_${verbuild ?: 'N/A'}"
                        ReleaseVersion = "${verversion}_${verbuild ?: 'N/A'}"
                      }
                      
                      def JDKFinal = "${filenameFinal}.${filenameSuffix}"
                      def SHAFinal = "${JDKFinal}.sha256.txt"
                      
                      // ReleaseVersion = "${verversion}_${verbuild ?: 'N/A'}"
                      
                      echo "JDK File Name : ${JDKFinal}"
                      echo "SHA File Name : ${SHAFinal}"
                      DLfilenames << JDKFinal
                      DLfilenames << SHAFinal

                      JDKArray << [ "${packageType}" , "${JDKFinal}", "${SHAFinal}" , "${distro}" , "${arch}" , "${ReleaseVersion}" ]
                    }

                    // Set Package Release Version If Repackage
                    if (params.RePackage) {
                        PackageReleaseVersion = params.Package_Increment
                      }

                      echo "Debug 01 - Parameters Including Pacakage Release Version"
                      // echo "Distro = ${distro}"
                      // echo "Product = ${PRODUCT}"
                      // echo "Package Release Version : ${PackageReleaseVersion}"
                }
            }
          }
// Process Parameters Stage - End
// Validate Artifacts Stage - Start
stage('Validate Artifacts') {
    agent { label NODE_LABEL }
    when {
        expression { return params.Release }
    }
    steps {
        script {
            echo "Validating Artifacts"
            echo "Tuples:"
            echo "${JDKArray}"

            JDKArray.each { ArrayElement ->
                def (PTYPE, PFILE, PSIGN, PDIST, PARCH, PVERS) = ArrayElement
                def Binurl = "${dlURL}/${PFILE}"
                def SHAurl = "${dlURL}/${PSIGN}"

                // Download binary and checksum
                validateAndDownloadArtifact(Binurl, PFILE)
                validateAndDownloadArtifact(SHAurl, PSIGN)

                // Validate checksum
                def calculatedChecksum = validateChecksum(PFILE, PSIGN)

                if (PARCH == "arm") {
                    upstreamversionARM32 = extractUpstreamVersionFromTar(PFILE)
                }

                // Cleanup temporary files
                cleanupFiles([PFILE, PSIGN])

                // Update array with the validated information
                ModifiedJDKArray << [PTYPE, PFILE, PSIGN, PDIST, PARCH, PVERS, calculatedChecksum, Binurl]
            }

            JDKArray = ModifiedJDKArray
        }
    }
}
// Generate Spec File Stage - Start
          stage('Generate Spec File') {
            agent { label NODE_LABEL }
            when {
                expression { return params.Release }
            }
              steps {
                  script {
                      echo "Validating Required Parameters For Generate Spec File Program"
                      echo "Debug 02"
                      JDKArray.each { ArrayElement ->
                      echo "${ArrayElement}"
                      // Assign Tuple Values To Vars
                      def PTYPE = ArrayElement[0]
                      def PFILE = ArrayElement[1]
                      def PSIGN = ArrayElement[2]
                      def PDIST = ArrayElement[3]
                      def PARCH = ArrayElement[4]
                      def PVERS = ArrayElement[5]
                      def PCSUM = ArrayElement[6]
                      def PKURL = ArrayElement[7]
                      

                      // Generate Date For Use In Various Places
                      def getDate = new Date(currentBuild.startTimeInMillis)
                      // Format The Date
                      def currentDate = getDate.format("EEE, dd MMM yyyy HH:mm:ss Z", TimeZone.getTimeZone('UTC'))
                      def currentDateRHEL = getDate.format("EEE MMM d yyyy", TimeZone.getTimeZone('UTC'))
                      echo "Current Date: ${currentDate}"
                      echo "Current Date RHEL: ${currentDateRHEL}"

                      // Setup List Of Packages To Build
                      if (PDIST == 'alpine-linux') {
                         DISTS_TO_BUILD = ['alpine']
                        } else if (PDIST == 'linux') {
                            DISTS_TO_BUILD = ['rhel', 'suse', 'debian']
                            } else {
                                error("Unsupported dist: ${PDIST}")
                                }
                      DISTS_TO_BUILD.each { DistArrayElement ->
                      
                      echo "Debug 03"
                      if (params.Tag?.startsWith("jdk8")) {
                        echo "Debug 04"
                        echo "PVERS : ${PVERS}"

                        def versionPattern = /(\d+)(u\d+)(b\d+)/
                        def versparser = (PVERS =~ versionPattern)
                        println("Full Match: ${versparser[0][0]}")
                        if (versparser.matches()) {
                            println("Full Match: ${versparser[0][0]}")
                            Release = versparser[0][1]
                            Version = versparser[0][2]
                            Build = versparser[0][3]
                            } else {
                                error("The version string format does not match the expected pattern.")
                                }
                      } else {
                        def versionPattern = /^(\d+)(?:\.(.*))?_(.+)$/
                        def versparser = (PVERS =~ versionPattern)
                        if (versparser.matches()) {
                          Release = versparser[0][1].toInteger()
                          Version = versparser[0][2] ? versparser[0][2] : "null"
                          Build = versparser[0][3]
                        } else {
                            error("Version string format is invalid: ${PVERS}")
                          }
                      }

                      def TemplateType = ArrayElement[0]
                      def packagever
                      packagearch = PARCH
                      def templatebase
                      def outputfile
                      def changelogversion
                    
                      // Python Script Requires 9 arguments
                      // 1. Template name
                      // 2. Package Version (in correct format)
                      // 3. Package Architecture (in correct format)
                      // 4. Package URL
                      // 5. Package Checksum
                      // 6. Package Filename
                      // 7. Output Filename
                      // 8. Current Date
                      // 9. Package Release Version
                      // 10. Code Upstream Version

                      // Reformat Any Variables For Distribution Specific Oddities

                      if (DistArrayElement == 'alpine') {
                        
                        // If Base Format Reqd = 23_p37 ( Upstream jdk-23+37 )
                        // If Updt Format Reqd = 23.0.1_p11 ( Upstream jdk-23.0.1+11 )
                        // If JKD8 Format Reqd = 8.432.06 ( Upstream jdk8u432b06 )
                        // Upstream Arch For Alpine : **/alpine-linux/x64/temurin/*.tar.gz,**/alpine-linux/x64/temurin/*.zip,**/alpine-linux/x64/temurin/*.sha256.txt,**/alpine-linux/x64/temurin/*.msi,**/alpine-linux/x64/temurin/*.pkg,**/alpine-linux/x64/temurin/*.json,**/alpine-linux/x64/temurin/*.sig
                        // Upstream Arch For Alpine ARM : **/alpine-linux/aarch64/temurin/*.tar.gz,**/alpine-linux/aarch64/temurin/*.zip,**/alpine-linux/aarch64/temurin/*.sha256.txt,**/alpine-linux/aarch64/temurin/*.msi,**/alpine-linux/aarch64/temurin/*.pkg,**/alpine-linux/aarch64/temurin/*.json,**/alpine-linux/aarch64/temurin/*.sig
                        
                        if (Version == "null") {
                            packagever = "${Release}_p${Build}"
                        } else {
                            packagever = "${Release}_${Version}_p${Build}"
                        }

                        // Upstream Version Is Not Required For Alpine
                        upstreamversion = ""

                        if (Release == "8" ) {
                            // Regular expression to split around 'u' and 'b'
                            def versionPattern = /(\d+)(u)(\d+)(b)(\d+)/
                            def versparser = (PVERS =~ versionPattern)
                            if (versparser.matches()) {
                                Release = versparser[0][1]   // Capture before 'u', e.g., "8"
                                Version = versparser[0][3]   // Capture between 'u' and 'b', e.g., "432"
                                Build = versparser[0][5]     // Capture after 'b', e.g., "06"
                                } else {
                                    error("The version string format does not match the expected pattern.")
                                    }
                            packagever = "${Release}.${Version}.${Build}"
                        }
                        // Reformat x64 For Alpine
                        if (PARCH == 'x64') {
                            packagearch = "x86_64"
                        }
                        outputfile = "APKBUILD"

                        echo "Debug 05 Python Parameters For Alpine"
                        echo "Python 1 : Template Path = : ${templatebase}"
                        echo "Python 2 : Package Version = : ${packagever}"
                        echo "Python 3 : Package Arch = : ${packagearch}"
                        echo "Python 4 : Package URL = : ${PKURL}"
                        echo "Python 5 : Package Checksum = : ${PCSUM}"
                        echo "Python 6 : Package Name = : ${PFILE}"
                        echo "Python 7 : Output File Name = : ${outputfile}"
                        echo "Python 8 : Current Date = : ${currentDate}"
                        echo "Python 9 : Package Release Version = : ${PackageReleaseVersion}"
                        echo "Python 10: JDK Upstream Version = : ${upstreamversion}"
                        echo "Python 11 : Changelog Version = :${packagever}"
                        echo "Python 12: ARM32 Version = ${upstreamversion}"

                        // Figure Out Template name
                        templatebase = "./linux_new/${PTYPE}/${DistArrayElement}/src/main/packaging/${PRODUCT}/${Release}/${DistArrayElement}.${PTYPE}${Release}.template.j2"

                        // Check If Template Exists
                        if (!fileExists(templatebase)) {
                          error("Template File Not Found At : ${templatebase}")
                        }

                        def speccmd = "python3 linux_new/generate_spec.py \"${templatebase}\" \"${packagever}\" \"${packagearch}\" \"${PKURL}\" \"${PCSUM}\" \"${PFILE}\" \"${outputfile}\" \"${currentDate}\" \"${PackageReleaseVersion}\" \"${upstreamversion}\" \"${packagever}\" \"${upstreamversion}\""
                        echo "Spec Command : ${speccmd}"
                        def genresult = sh(script: speccmd, returnStatus: true)
                        echo "Result : ${genresult}"
                      } 

                      if (DistArrayElement == 'debian') {

                        echo "Debug 06 Python Parameters For Debian"
                        // If Base Format Reqd = 23.0.0.0.0+37 ( Upstream jdk-23+37 )
                        // If Updt Format Reqd = 23.0.1.0.0+11 ( Upstream jdk-23.0.1+11 )
                        // If Rebuild Format Reqd = 23.0.1.1.0+5 ( Upstream jdk-23.0.1.1+5 )
                        // If JDK8 8.0.432.0.0+6
                        // Upstream Arch For x64 : **/linux/x64/temurin/*.tar.gz,**/linux/x64/temurin/*.zip,**/linux/x64/temurin/*.sha256.txt,**/linux/x64/temurin/*.msi,**/linux/x64/temurin/*.pkg,**/linux/x64/temurin/*.json,**/linux/x64/temurin/*.sig
                        // Upstream Arch For ARM64 : **/linux/aarch64/temurin/*.tar.gz,**/linux/aarch64/temurin/*.zip,**/linux/aarch64/temurin/*.sha256.txt,**/linux/aarch64/temurin/*.msi,**/linux/aarch64/temurin/*.pkg,**/linux/aarch64/temurin/*.json,**/linux/aarch64/temurin/*.sig
                        // Upstream Arch For s390x : **/linux/s390x/temurin/*.tar.gz,**/linux/s390x/temurin/*.zip,**/linux/s390x/temurin/*.sha256.txt,**/linux/s390x/temurin/*.msi,**/linux/s390x/temurin/*.pkg,**/linux/s390x/temurin/*.json,**/linux/s390x/temurin/*.sig
                        // Upstream Arch For ppc64le : **/linux/ppc64le/temurin/*.tar.gz,**/linux/ppc64le/temurin/*.zip,**/linux/ppc64le/temurin/*.sha256.txt,**/linux/ppc64le/temurin/*.msi,**/linux/ppc64le/temurin/*.pkg,**/linux/ppc64le/temurin/*.json,**/linux/ppc64le/temurin/*.sig
                        // Upstream Arch For RISCV : **/linux/riscv64/temurin/*.tar.gz,**/linux/riscv64/temurin/*.zip,**/linux/riscv64/temurin/*.sha256.txt,**/linux/riscv64/temurin/*.msi,**/linux/riscv64/temurin/*.pkg,**/linux/riscv64/temurin/*.json,**/linux/riscv64/temurin/*.sig
                        // Upstream Arch For ARM32 : **/linux/arm/temurin/*.tar.gz,**/linux/arm/temurin/*.zip,**/linux/arm/temurin/*.sha256.txt,**/linux/arm/temurin/*.msi,**/linux/arm/temurin/*.pkg,**/linux/arm/temurin/*.json,**/linux/arm/temurin/*.sig
                        
                        // Debian Requires 3 Files To Be Generated
                        def debianFiles = ['changelog', 'control', 'rules']

                          if (Release == "8" ) {
                            echo "Debian JDK8"
                            // Extract components from original format
                            def major = PVERS[0]           // Extract major version '8'
                            def versparser = (PVERS =~ /(\d+)u(\d+)b(\d+)/)
                            def minor = versparser[0][2]  // Extract '432'
                            def build = versparser[0][3].replaceAll(/^0+/, '')    // Extract '6'
                            // Construct the new format
                            packagever = "${major}.0.${minor}.0.0+${build}"
                        } else {
                            echo "Debian Not JDK8"
                            if (Version == "null") {
                                packagever = "${Release}.0.0.0.0+${Build}"
                            } else {
                                packagever = "${Release}.${Version}.0+${Build}"
                            }
                            echo "Debian PackageVer = ${packagever}"
                        }

                        // // Override Build Dists For Debian
                        // PKGBUILDLABEL = (PARCH == 'x64') ? 'build&&linux&&x64&&dockerBuild&&dynamicAzure' :
                        //                 (PARCH == 'aarch64') ? 'armv8&&build&&dockerBuild&&dockerhost' :
                        //                 (PARCH == 'ppc64le') ? 'linux&&dockerBuild&&dockerHost&&ppc64le' :
                        //                 (PARCH == 's390x') ? 'linux&&dockerBuild&&dockerHost&&s390x' :
                        //                 (PARCH == 'arm') ? 'armv8&&build&&dockerBuild&&dockerhost' :
                        //                 (PARCH == 'riscv64') ? 'riscv64&&dockerInstaller' :
                        //                 'build&&linux&&x64&&dockerBuild&&dynamicAzure'

                        echo "Debug 07"
                        echo "PVERS : ${PVERS}"
                        echo "Release = ${Release}"
                        echo "Version = ${Version}"
                        echo "Build = ${Build}"
                        echo "PackageVer = ${packagever}"
                        echo "PackageArch = ${packagearch}"

                        debianFiles.each { debianFilesArrayElement -> 

                        echo "Processing Debian ${debianFilesArrayElement} File"
                        outputfile = debianFilesArrayElement

                        // Figure Out Template name
                        templatebase = "./linux_new/${PTYPE}/${DistArrayElement}/src/main/packaging/${PRODUCT}/${Release}/${DistArrayElement}/${debianFilesArrayElement}.template.j2"

                        // Check If Template Exists
                        if (!fileExists(templatebase)) {
                          error("Template File Not Found At : ${templatebase}")
                        }

                        echo "Debug 08"
                        echo "Python 1 : Template Path = : ${templatebase}"
                        echo "Python 2 : Package Version = : ${packagever}"
                        echo "Python 3 : Package Arch = : ${packagearchDeb}"
                        echo "Python 4 : Package URL = : ${PKURL}"
                        echo "Python 5 : Package Checksum = : ${PCSUM}"
                        echo "Python 6 : Package Name = : ${PFILE}"
                        echo "Python 7 : Output File Name = : ${outputfile}"
                        echo "Python 8 : Current Date = : ${currentDate}"
                        echo "Python 9 : Package Release Version = : ${PackageReleaseVersion}"
                        echo "Python 10: Upstream Version = : ${upstreamversion}"
                        echo "Python 11: Changelog Version = : ${packagever}"
                        echo "Python 12: ARM32 Version = ${upstreamversion}"

                        def speccmd = "python3 linux_new/generate_spec.py \"${templatebase}\" \"${packagever}\" \"${packagearchDeb}\" \"${PKURL}\" \"${PCSUM}\" \"${PFILE}\" \"${outputfile}\" \"${currentDate}\" \"${PackageReleaseVersion}\" \"${upstreamversion}\" \"${packagever}\" \"${upstreamversion}\""
                        echo "Spec Command : ${speccmd}"
                        def genresult = sh(script: speccmd, returnStatus: true)
                        echo "Result : ${genresult}"
                        
                        }

                      } 
                        
                        if (DistArrayElement == "rhel" || DistArrayElement == "suse") {
                        echo "Debug 09 - Rhel & Suse"
                        echo "PVERS : ${PVERS}"
                        echo "Release = ${Release}"
                        echo "Version = ${Version}"
                        echo "Build = ${Build}"
                        echo "PackageVer = ${packagever}"
                        echo "PackageArch = ${packagearch}"

                        if (Release == "8" ) {
                            echo "RHEL/SUSE JDK8"
                            upstreamversion = params.Tag.replaceFirst("^jdk", "")
                            // Extract components from original format
                            def major = PVERS[0]           // Extract major version '8'
                            def versparser = (PVERS =~ /(\d+)u(\d+)b(\d+)/)
                            def minor = versparser[0][2]  // Extract '432'
                            def build = versparser[0][3].replaceAll(/^0+/, '')    // Extract '6'
                            def formattedBuild = build.toString()padLeft(2, '0')
                            // Construct the new format
                            packagever = "${major}.0.${minor}.0.0.${build}"
                            changelogversion = "${major}.0.${minor}-b${formattedBuild}"
                        } else {
                            echo "RHEL/SUSE Not JDK8"
                            echo "Deubg 09A - ${PVERS}"
                            upstreamversion = params.Tag.replaceFirst("^jdk-", "")

                            // def major = PVERS[0]           // Extract major version '8'
                            // def versparser = (PVERS =~ /(\d+)u(\d+)b(\d+)/)
                            // def minor = versparser[0][2]  // Extract '432'
                            // def build = versparser[0][3].replaceAll(/^0+/, '')    // Extract '6'
                            // def formattedBuild = build.toString()padLeft(2, '0')
                            if (Version == "null") {
                                packagever = "${Release}.0.0.0.0.${Build}"
                                changelogversion = "${Release}.0.${Version}+${Build}"
                            } else {
                                packagever = "${Release}.${Version}.0.${Build}"
                                changelogversion = "${Release}.0.${Version}+${Build}"
                            }
                        }

                        // Override Build Dists For RHEL ( always builds on x64 )
                        // PKGBUILDLABEL = 'build&&linux&&x64&&dockerBuild&&dynamicAzure'
                        // PKGBUILDLABEL = 'dockerhost-azure-ubuntu2204-x64-1'

                        // Figure Out Upstream Version

                        

                        if (PARCH == 'arm') {
                        // If JDK8 ARM32, Then Need To Deduce Correct Upstream
                        echo "DEBUG00A - Get ARM32 Upstream Version #"
                        echo "PARCH = ${PARCH}"
                        upstreamversionARM32 = upstreamversionARM32.replaceFirst("^jdk", "")
                        upstreamversionARM32 = upstreamversionARM32.replaceAll(/-(jre|jdk)$/, "")
                        echo "Upstream ARM32 : ${upstreamversionARM32}"
                        echo "upstreamVersion : ${upstreamversion}"
                        // DONE
                        }

                        // Figure Out Changelog Version
                        // JDK8   = 8.0.432-b06
                        // JDK11+ = 11.0.12+7

                        // Figure Out Template name
                        templatebase = "./linux_new/${PTYPE}/${DistArrayElement}/src/main/packaging/${PRODUCT}/${Release}/${PRODUCT}-${Release}-${PTYPE}.template.j2"
                        // Output File Name Only ( defaults to outputting in same location as template )
                        outputfile = "${PRODUCT}-${Release}-${PTYPE}.spec"
                        
                        // Check If Template Exists
                        if (!fileExists(templatebase)) {
                          error("Template File Not Found At : ${templatebase}")
                        }

                        echo "Debug - 09a - PackageVer = ${packagever}"
                        echo "Python 1 : Template Path = : ${templatebase}"
                        echo "Python 2 : Package Version = : ${packagever}"
                        echo "Python 3 : Package Arch = : ${packagearchRhel}"
                        echo "Python 4 : Package URL = : ${PKURL}"
                        echo "Python 5 : Package Checksum = : ${PCSUM}"
                        echo "Python 6 : Package Name = : ${PFILE}"
                        echo "Python 7 : Output File Name = : ${outputfile}"
                        echo "Python 8 : Current Date = : ${currentDateRHEL}"
                        echo "Python 9 : Package Release Version = : ${PackageReleaseVersion}"
                        echo "Python 10: Upstream Version = : ${upstreamversion}"
                        echo "Python 11: Changelog Version = : ${changelogversion}"
                        echo "Python 12: Upstream ARM32 Version = : ${upstreamversionARM32}"

                        def speccmd = "python3 linux_new/generate_spec.py \"${templatebase}\" \"${packagever}\" \"${packagearchRhel}\" \"${PKURL}\" \"${PCSUM}\" \"${PFILE}\" \"${outputfile}\" \"${currentDateRHEL}\" \"${PackageReleaseVersion}\" \"${upstreamversion}\" \"${changelogversion}\" \"${upstreamversionARM32}\""
                        echo "Spec Command : ${speccmd}"
                        def genresult = sh(script: speccmd, returnStatus: true)
                        echo "Result : ${genresult}"

                        // End Of RHEL SUSE CODE
                      }

                      }

                      }
                    
                    // Tar And Publish The Generated Build Files
                    // May Need Rework
                       sh "tar -czf ./package_build_files.tar.gz ./linux_new/*"
                       sh "pwd"
                       sh "ls -ltr"
                       // Publish the tarball
                       archiveArtifacts artifacts: "package_build_files.tar.gz", allowEmptyArchive: false
                    // Stash The Generated Build Files
                    dir('linux_new') {
                    stash name: 'installercode', includes: '**'
                      
                      
                    }
                  }
              }
          }
// Generate Spec File Stage - End
// Build And Archive Packages Stage - Start
stage('Build & Archive Package') {
    when {
        expression { return params.Release }
    }
    steps {
        script {
            DISTS_TO_BUILD.each { DistArrayElement ->
                def nodeLabel = ''
                if (DistArrayElement == 'alpine') {
                    nodeLabel = PKGBUILDLABELAPK
                } else if (DistArrayElement == 'debian') {
                    nodeLabel = PKGBUILDLABELDEB
                } else if (DistArrayElement in ['rhel', 'suse']) {
                    nodeLabel = PKGBUILDLABELRHEL
                } else {
                    error "Unknown DistArrayElement: ${DistArrayElement}"
                }

                node(label: nodeLabel) { // Assign node dynamically based on distribution type
                    echo "Build Packages For Arch: ${arch}"
                    echo "Build Packages For PARCH: ${packagearch}"
                    echo "Building For Dist: ${DistArrayElement}"
                    echo "Build Product: ${PRODUCT}"
                    echo "Build Version : ${Release}"

                    // Docker --mount option requires BuildKit
                    env.DOCKER_BUILDKIT = 1
                    env.COMPOSE_DOCKER_CLI_BUILD = 1

                    // Prepare Workspace
                    cleanWs()
                    unstash 'installercode'

                    try {
                        def PackagesToBuild = ['jdk', 'jre']
                        def buildCli
                        PackagesToBuild.each { PackageArrayElement ->
                            echo "Building Package: ${PackageArrayElement} for ${DistArrayElement}"
                            def gBuildTask = (packagearch in ['x86_64', 'amd64']) ?
                                "package${PackageArrayElement}${DistArrayElement} check${PackageArrayElement}${DistArrayElement}" :
                                "package${PackageArrayElement}${DistArrayElement}"
                            
                            // Override Package Arch To Be Dist Specific

                            if (DistArrayElement == "rhel" || DistArrayElement == "suse") {
                              echo "Using build CLI for RHEL/SUSE: ${buildCli}"
                              buildCli = "./gradlew ${gBuildTask} --parallel -PPRODUCT=${PRODUCT} -PPRODUCT_VERSION=${Release} -PARCH=${packagearchRhel}"
                            } else if (DistArrayElement == "debian") {
                               echo "Using build CLI for Debian: ${buildCli}"
                               buildCli = "./gradlew ${gBuildTask} --parallel -PPRODUCT=${PRODUCT} -PPRODUCT_VERSION=${Release} -PARCH=${packagearchDeb}"
                            } else {
                              echo "Using default build CLI: ${buildCli}"
                              buildCli = "./gradlew ${gBuildTask} --parallel -PPRODUCT=${PRODUCT} -PPRODUCT_VERSION=${Release} -PARCH=${packagearch}"
                            }
                                             
                            if (params.enableGpgSigning) {
                                def privateKey = 'adoptium-artifactory-rsa-key'
                                withCredentials([file(credentialsId: privateKey, variable: 'GPG_KEY')]) {
                                    buildCli += " -PGPG_KEY_PATH=${GPG_KEY}"
                                }
                            }

                            buildCli = params.enableDebug.toBoolean() ? buildCli + ' --stacktrace' : buildCli
                            echo "Build CLI : ${buildCli}"
                            sh("$buildCli")
                        }
                    } catch (Exception ex) {
                        echo "Exception in build for ${DistArrayElement}: ${ex}"
                        currentBuild.result = 'FAILURE'
                    } finally {
                        archiveArtifacts artifacts: '**/build/ospackage/*,**/build/reports/**,**/packageTest/dependencies/deb/*',
                                         onlyIfSuccessful: false, allowEmptyArchive: false
                    }
                }
            }
        }
    }
}
// Build And Archive Packages Stage - End
// Publish Packages Stage - Start
          stage('Publish Packages') {
            agent { label NODE_LABEL }
            tools {
                jfrog 'jfrog-cli'
                }
            when {
                expression { return params.Release }
            }
              steps {
                  script {
                      echo "Publish Packages"
                  }
              }
          }
// Publish Packages Stage - End
  }
// Stage Definition - End
}
// Pipeline Definition - End
