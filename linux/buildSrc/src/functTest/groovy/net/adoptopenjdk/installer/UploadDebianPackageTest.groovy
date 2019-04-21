package net.adoptopenjdk.installer

import com.jayway.jsonpath.Configuration
import com.jayway.jsonpath.JsonPath
import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import okhttp3.mockwebserver.RecordedRequest
import org.gradle.testkit.runner.GradleRunner
import org.gradle.testkit.runner.TaskOutcome
import org.gradle.testkit.runner.UnexpectedBuildFailure
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir

import static org.assertj.core.api.Assertions.assertThat
import static org.assertj.core.api.Assertions.fail

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
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"aPackage\",\"linked\":false}]")

        this.mws.enqueue(indexResponse)

        MockResponse uploadResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

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
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
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

        RecordedRequest indexRequest = this.mws.takeRequest()
        assertThat(indexRequest.method).isEqualTo("GET")
        assertThat(indexRequest.path).isEqualTo("/repos/aSubject/aRepository/packages")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path).isEqualTo(
                "/content/aSubject/aRepository/aPackage/1.0.0/pool/main/a/aPackage/upload.deb"
        )
        assertThat(uploadRequest.getHeader("Authorization")).isEqualTo("Basic YVVzZXI6YUtleQ==")
        assertThat(uploadRequest.getHeader("X-Bintray-Publish")).isEqualTo("0")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Distribution")).isEqualTo("jessie,xenial")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Component")).isEqualTo("main")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Architecture")).isEqualTo("amd64")
        assertThat(uploadRequest.getBody().readUtf8()).isEqualTo("I'm not a real Debian package.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void debianPackageNotUploadedIfArchitectureNotConfigured() {
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"aPackage\",\"linked\":false}]")

        this.mws.enqueue(indexResponse)

        settingsFile << "rootProject.name = 'deb'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadDebianPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
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

        assertThat(this.mws.requestCount).isEqualTo(1)

        RecordedRequest request = this.mws.takeRequest()

        assertThat(request.method).isEqualTo("GET")
        assertThat(request.path).isEqualTo("/repos/aSubject/aRepository/packages")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void debianPackageUploadedAndPublishedIfEnabled() {
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"aPackage\",\"linked\":false}]")

        this.mws.enqueue(indexResponse)

        MockResponse mockResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

        this.mws.enqueue(mockResponse)

        settingsFile << "rootProject.name = 'deb'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadDebianPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
                architecture = "amd64"
                autoPublish = true
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

        assertThat(this.mws.requestCount).isEqualTo(2)

        RecordedRequest indexRequest = this.mws.takeRequest()
        assertThat(indexRequest.method).isEqualTo("GET")
        assertThat(indexRequest.path).isEqualTo("/repos/aSubject/aRepository/packages")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path)
                .isEqualTo("/content/aSubject/aRepository/aPackage/1.0.0/pool/main/a/aPackage/upload.deb")

        assertThat(uploadRequest.getHeader("Authorization")).isEqualTo("Basic YVVzZXI6YUtleQ==")
        assertThat(uploadRequest.getHeader("X-Bintray-Publish")).isEqualTo("1")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Distribution")).isEqualTo("jessie,xenial")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Component")).isEqualTo("main")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Architecture")).isEqualTo("amd64")
        assertThat(uploadRequest.getBody().readUtf8()).isEqualTo("I'm not a real Debian package.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void packageCreatedIfAbsentAndAutoCreationEnabled() {
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"anotherPackage\",\"linked\":false}]")

        MockResponse creationResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

        MockResponse uploadResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

        this.mws.enqueue(indexResponse)
        this.mws.enqueue(creationResponse)
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
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
                architecture = "amd64"
                autoPublish = true
                autoCreatePackage = true
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

        RecordedRequest indexRequest = this.mws.takeRequest()

        assertThat(indexRequest.method).isEqualTo("GET")
        assertThat(indexRequest.path).isEqualTo("/repos/aSubject/aRepository/packages")

        RecordedRequest creationRequest = this.mws.takeRequest()
        Object document = parseJson(creationRequest.body.readUtf8())

        assertThat(creationRequest.method).isEqualTo("POST")
        assertThat(creationRequest.path).isEqualTo("/packages/aSubject/aRepository")
        assertThat(JsonPath.read(document, '$.name')).isEqualTo("aPackage")
        assertThat(JsonPath.read(document, '$.desc')).isEqualTo("This is a description.")
        assertThat(JsonPath.read(document, '$.licenses.*')).containsOnly("GPL-2.0+CE")
        assertThat(JsonPath.read(document, '$.desc')).isEqualTo("This is a description.")
        assertThat(JsonPath.read(document, '$.public_download_numbers')).isFalse()
        assertThat(JsonPath.read(document, '$.public_stats')).isFalse()
        assertThat(JsonPath.read(document, '$.vcs_url')).isEqualTo("https://example.com/vcs")
        assertThat(JsonPath.read(document, '$.website_url')).isEqualTo("https://example.com/")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path)
                .isEqualTo("/content/aSubject/aRepository/aPackage/1.0.0/pool/main/a/aPackage/upload.deb")

        assertThat(uploadRequest.getHeader("Authorization")).isEqualTo("Basic YVVzZXI6YUtleQ==")
        assertThat(uploadRequest.getHeader("X-Bintray-Publish")).isEqualTo("1")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Distribution")).isEqualTo("jessie,xenial")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Component")).isEqualTo("main")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Architecture")).isEqualTo("amd64")
        assertThat(uploadRequest.getBody().readUtf8()).isEqualTo("I'm not a real Debian package.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void packageNotCreatedIfAutoCreationEnabledAndItAlreadyExists() {
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"aPackage\",\"linked\":false}]")

        MockResponse uploadResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

        this.mws.enqueue(indexResponse)
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
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
                architecture = "amd64"
                autoPublish = true
                autoCreatePackage = true
                releaseArchitecture amd64: [
                    debian: ["jessie", "stretch"]
                ]
            }
        """

        def result = GradleRunner.create()
                .withProjectDir(tempProjectDir)
                .withArguments("uploadPackage")
                .withPluginClasspath()
                .build()

        assertThat(this.mws.requestCount).isEqualTo(2)

        RecordedRequest indexRequest = this.mws.takeRequest()

        assertThat(indexRequest.method).isEqualTo("GET")
        assertThat(indexRequest.path).isEqualTo("/repos/aSubject/aRepository/packages")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path)
                .isEqualTo("/content/aSubject/aRepository/aPackage/1.0.0/pool/main/a/aPackage/upload.deb")

        assertThat(uploadRequest.getHeader("Authorization")).isEqualTo("Basic YVVzZXI6YUtleQ==")
        assertThat(uploadRequest.getHeader("X-Bintray-Publish")).isEqualTo("1")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Distribution")).isEqualTo("jessie,stretch")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Component")).isEqualTo("main")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Architecture")).isEqualTo("amd64")
        assertThat(uploadRequest.getBody().readUtf8()).isEqualTo("I'm not a real Debian package.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void packageUpdatedIfAutoUpdateEnabledAndItAlreadyExists() {
        MockResponse indexResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"aPackage\",\"linked\":false}]")

        MockResponse updateResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

        MockResponse uploadResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}")

        this.mws.enqueue(indexResponse)
        this.mws.enqueue(updateResponse)
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
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
                architecture = "s390x"
                autoPublish = true
                autoUpdatePackage = true
                releaseArchitecture amd64: [
                    debian: ["jessie", "stretch"],
                    ubuntu: ["trusty", "xenial"]
                ]
                releaseArchitecture s390x: [
                    debian: ["jessie", "stretch"]
                ]
            }
        """

        def result = GradleRunner.create()
                .withProjectDir(tempProjectDir)
                .withArguments("uploadPackage")
                .withPluginClasspath()
                .build()

        assertThat(this.mws.requestCount).isEqualTo(3)

        RecordedRequest indexRequest = this.mws.takeRequest()

        assertThat(indexRequest.method).isEqualTo("GET")
        assertThat(indexRequest.path).isEqualTo("/repos/aSubject/aRepository/packages")

        RecordedRequest updateRequest = this.mws.takeRequest()
        Object document = parseJson(updateRequest.body.readUtf8())

        assertThat(updateRequest.method).isEqualTo("PATCH")
        assertThat(updateRequest.path).isEqualTo("/packages/aSubject/aRepository/aPackage")
        assertThat(JsonPath.read(document, '$.desc')).isEqualTo("This is a description.")
        assertThat(JsonPath.read(document, '$.licenses.*')).containsOnly("GPL-2.0+CE")
        assertThat(JsonPath.read(document, '$.desc')).isEqualTo("This is a description.")
        assertThat(JsonPath.read(document, '$.public_download_numbers')).isFalse()
        assertThat(JsonPath.read(document, '$.public_stats')).isFalse()
        assertThat(JsonPath.read(document, '$.vcs_url')).isEqualTo("https://example.com/vcs")
        assertThat(JsonPath.read(document, '$.website_url')).isEqualTo("https://example.com/")

        RecordedRequest uploadRequest = this.mws.takeRequest()

        assertThat(uploadRequest.path)
                .isEqualTo("/content/aSubject/aRepository/aPackage/1.0.0/pool/main/a/aPackage/upload.deb")

        assertThat(uploadRequest.getHeader("Authorization")).isEqualTo("Basic YVVzZXI6YUtleQ==")
        assertThat(uploadRequest.getHeader("X-Bintray-Publish")).isEqualTo("1")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Distribution")).isEqualTo("jessie,stretch")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Component")).isEqualTo("main")
        assertThat(uploadRequest.getHeader("X-Bintray-Debian-Architecture")).isEqualTo("s390x")
        assertThat(uploadRequest.getBody().readUtf8()).isEqualTo("I'm not a real Debian package.")

        assertThat(result.task(":uploadPackage").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void packageUploadResultsInExceptionIfPackageDoesNotExist() {
        MockResponse response = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"anotherPackage\",\"linked\":false}]")

        this.mws.enqueue(response)

        settingsFile << "rootProject.name = 'deb'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            tasks.register("uploadPackage", net.adoptopenjdk.installer.UploadDebianPackage) {
                packageToPublish = file('${this.fileToUpload.getAbsolutePath()}')
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                key = "aKey"
                subject = "aSubject"
                repository = "aRepository"
                packageName = "aPackage"
                packageVersion = "1.0.0"
                packageDescription = "This is a description."
                websiteUrl = "https://example.com/"
                vcsUrl = "https://example.com/vcs"
                licenses = ["GPL-2.0+CE"]
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

        try {
            GradleRunner.create()
                    .withProjectDir(tempProjectDir)
                    .withArguments("uploadPackage")
                    .withPluginClasspath()
                    .build()

            fail("An UnexpectedBuildFailure should have been thrown")
        } catch (UnexpectedBuildFailure e) {
            // expected
        }

        assertThat(this.mws.requestCount).isEqualTo(1)

        RecordedRequest indexRequest = this.mws.takeRequest()
        assertThat(indexRequest.method).isEqualTo("GET")
        assertThat(indexRequest.path).isEqualTo("/repos/aSubject/aRepository/packages")
    }

    private static Object parseJson(String json) {
        return Configuration.defaultConfiguration().jsonProvider().parse(json)
    }
}
