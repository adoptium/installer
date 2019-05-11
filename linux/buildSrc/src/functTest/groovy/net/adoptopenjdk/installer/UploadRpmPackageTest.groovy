package net.adoptopenjdk.installer

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.gradle.testkit.runner.GradleRunner
import org.gradle.testkit.runner.TaskOutcome
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

import static org.assertj.core.api.Assertions.assertThat

class UploadRpmPackageTest {

    @TempDir
    public File tempProjectDir

    File settingsFile
    File buildFile
    File fileToUpload

    MockWebServer mws = new MockWebServer()

    @BeforeEach
    void setUp() {
        settingsFile = new File(tempProjectDir, "settings.gradle")
        buildFile = new File(tempProjectDir, "build.gradle")
        fileToUpload = new File(tempProjectDir, "upload.rpm")

        fileToUpload << "I'm not a real RPM."
    }

    @AfterEach
    void tearDown() {
        this.mws.shutdown()
    }

    @Test
    void rpmsUploadedForRedHat6() {
        String responseBody = """
            {
              "repo" : "aRepsitory",
              "path" : "/aRepository/rhel/6/x86_64/Packages/upload.rpm",
              "created" : "2019-05-11T11:28:17.736Z",
              "createdBy" : "janedoe",
              "downloadUri" : "https://example.com/artifactory/aRepository/rhel/6/x86_64/Packages/upload.rpm",
              "mimeType" : "application/x-debian-package",
              "size" : "1024",
              "checksums" : {
                "sha1" : "27143b11fe844009341825044fc073278e29b8db",
                "md5" : "4ea625953eb11cb840016e5175ad2922",
                "sha256" : "84664eb409ddf1b11f8b425aaafe3be30a8fb7e939fd65a418c05ec7cd4c00e3"
              },
              "originalChecksums" : {
                "sha1" : "27143b11fe844009341825044fc073278e29b8db",
                "sha256" : "84664eb409ddf1b11f8b425aaafe3be30a8fb7e939fd65a418c05ec7cd4c00e3"
              },
              "uri" : "https://example.com/artifactory/aRepository/rhel/6/x86_64/Packages/upload.rpm"
            }
        """

        MockResponse checksumResponse = new MockResponse()
                .setResponseCode(404)

        this.mws.enqueue(checksumResponse)

        MockResponse uploadResponse = new MockResponse()
                .setResponseCode(201)
                .setBody(responseBody)

        this.mws.enqueue(uploadResponse)

        settingsFile << "rootProject.name = 'rpm'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadRpmPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                password = "aKey"
                repository = "aRepository"
                packageName = "aPackage"
                architecture = "x86_64"
                releaseArchitecture x86_64: [
                    rhel  : ["6"]
                ]
            }
        """

        def result = GradleRunner.create()
                .withProjectDir(tempProjectDir)
                .withArguments("uploadPackage")
                .withPluginClasspath()
                .build()

        assertThat(this.mws.requestCount).isEqualTo(2)

        RecordedRequest checksumRequest = this.mws.takeRequest()

        assertThat(checksumRequest.path)
                .isEqualTo("/aRepository/rhel/6/x86_64/Packages/upload.rpm")
        assertThat(checksumRequest.getHeader("X-Checksum-Deploy"))
                .isEqualTo("true")
        assertThat(checksumRequest.getHeader("X-Checksum-Sha1"))
                .isEqualTo("bd05570872591922e40975e8d0e6f4089504dc32")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path)
                .isEqualTo("/aRepository/rhel/6/x86_64/Packages/upload.rpm")
        assertThat(uploadRequest.getBody().readUtf8())
                .isEqualTo("I'm not a real RPM.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void rpmsNotUploadedIfArchitectureNotConfigured() {
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"aPackage\",\"linked\":false}]")

        this.mws.enqueue(indexResponse)

        settingsFile << "rootProject.name = 'rpm'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadRpmPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                password = "aKey"
                repository = "aRepository"
                packageName = "aPackage"
                architecture = "x390x"
                releaseArchitecture x86_64: [
                    rhel  : ["6", "7"]
                ]
            }
        """

        def result = GradleRunner.create()
                .withProjectDir(tempProjectDir)
                .withArguments("uploadPackage")
                .withPluginClasspath()
                .build()

        assertThat(this.mws.requestCount).isEqualTo(0)

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }
}
