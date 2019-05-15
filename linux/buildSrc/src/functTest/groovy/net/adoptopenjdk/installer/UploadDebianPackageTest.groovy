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

class UploadDebianPackageTest {

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
        fileToUpload = new File(tempProjectDir, "upload.deb")

        fileToUpload << "I'm not a real Debian package."
    }

    @AfterEach
    void tearDown() {
        this.mws.shutdown()
    }

    @Test
    void debianPackageUploadedForXenialAndJessie() {
        String responseBody = """
            {
              "repo" : "aRepsitory",
              "path" : "/aRepository/pool/main/a/aPackage/upload.deb",
              "created" : "2019-05-11T11:28:17.736Z",
              "createdBy" : "janedoe",
              "downloadUri" : "https://example.com/artifactory/aRepository/pool/main/a/aPackage/upload.deb",
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
              "uri" : "https://example.com/artifactory/aRepository/pool/main/a/aPackage/upload.deb"
            }
        """
        MockResponse checksumResponse = new MockResponse()
                .setResponseCode(404)

        this.mws.enqueue(checksumResponse)

        MockResponse uploadResponse = new MockResponse()
                .setResponseCode(201)
                .setBody(responseBody)

        this.mws.enqueue(uploadResponse)

        settingsFile << "rootProject.name = 'deb'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadDebianPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                password = "aKey"
                repository = "aRepository"
                packageName = "aPackage"
                architecture = "amd64"
                releaseArchitecture amd64: [
                    debian: ["jessie"],
                    ubuntu: ["xenial"]
                ]
                releaseArchitecture s390x: [
                    debian: ["jessie"],
                    ubuntu: ["xenial"]
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
                .isEqualTo("/aRepository/pool/main/a/aPackage/upload.deb;deb.component=main;deb.distribution=jessie;deb.distribution=xenial;deb.architecture=amd64")
        assertThat(checksumRequest.getHeader("X-Checksum-Deploy"))
                .isEqualTo("true")
        assertThat(checksumRequest.getHeader("X-Checksum-Sha1"))
                .isEqualTo("60aa43d3075e2359dfbdfca00ae63b4f6ae486e4")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path)
                .isEqualTo("/aRepository/pool/main/a/aPackage/upload.deb;deb.component=main;deb.distribution=jessie;deb.distribution=xenial;deb.architecture=amd64")
        assertThat(uploadRequest.getBody().readUtf8())
                .isEqualTo("I'm not a real Debian package.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void debianPackageNotUploadedIfArchitectureNotConfigured() {
        settingsFile << "rootProject.name = 'deb'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadDebianPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                password = "aKey"
                repository = "aRepository"
                packageName = "aPackage"
                architecture = "x390x"
                releaseArchitecture amd64: [
                    debian: ["jessie"],
                    ubuntu: ["xenial"]
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
