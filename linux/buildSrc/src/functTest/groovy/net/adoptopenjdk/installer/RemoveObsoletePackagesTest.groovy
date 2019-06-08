package net.adoptopenjdk.installer

import okhttp3.Credentials
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

class RemoveObsoletePackagesTest {
    @TempDir
    public File tempProjectDir

    File settingsFile
    File buildFile

    MockWebServer mws = new MockWebServer()

    @BeforeEach
    void setUp() {
        settingsFile = new File(tempProjectDir, "settings.gradle")
        buildFile = new File(tempProjectDir, "build.gradle")
    }

    @AfterEach
    void tearDown() {
        this.mws.shutdown()
    }

    @Test
    void debPackagesRemovedThatAreOlderThanSevenDays() {
        String searchResponseBody = """
            {
              "results" : [ {
                "uri" : "https://example.com/api/storage/deb-nightly/dists/bionic/main/binary-i386/Packages",
                "created" : "2019-05-15T20:01:56.257Z"
              }, {
                "uri" : "https://example.com/api/storage/deb-nightly/dists/bionic/main/binary-i386/Packages.bz2",
                "created" : "2019-05-15T20:01:56.586Z"
              }, {
                "uri" : "https://example.com/api/storage/deb-nightly/dists/bionic/main/binary-i386/Packages.gz",
                "created" : "2019-05-15T20:01:56.557Z"
              }, {
                "uri" : "https://example.com/api/storage/deb-nightly/pool/main/a/adoptopenjdk-11-hotspot/adoptopenjdk-11-hotspot_11.0.3+7-201905151809-1_amd64.deb",
                "created" : "2019-05-16T00:43:15.522Z"
              }, {
                "uri" : "https://example.com/api/storage/deb-nightly/pool/main/a/adoptopenjdk-11-hotspot/adoptopenjdk-11-hotspot_11.0.3+7-201905151811-1_ppc64el.deb",
                "created" : "2019-05-16T02:14:12.282Z"
              } ]
            }
        """
        MockResponse searchResponse = new MockResponse()
                .setResponseCode(200)
                .setBody(searchResponseBody)

        this.mws.enqueue(searchResponse)

        MockResponse deleteResponse = new MockResponse()
                .setResponseCode(204)

        // Two deb packages should be deleted
        this.mws.enqueue(deleteResponse)
        this.mws.enqueue(deleteResponse)

        settingsFile << "rootProject.name = 'deb'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            import java.time.Instant
            import java.time.ZoneId
            tasks.register("removeDebianNightlyBuilds", net.adoptopenjdk.installer.RemoveObsoletePackages) {
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                password = "aKey"
                repository = "deb-nightly"
                daysToKeep = 7
                clock = Clock.fixed(Instant.ofEpochMilli(1559993456971), ZoneId.of("UTC"))
            }
        """

        def result = GradleRunner.create()
                .withProjectDir(tempProjectDir)
                .withArguments("removeDebianNightlyBuilds")
                .withPluginClasspath()
                .build()

        assertThat(this.mws.requestCount).isEqualTo(3)

        RecordedRequest searchRequest = this.mws.takeRequest()

        assertThat(searchRequest.path)
                .isEqualTo("/api/search/creation?from=0&to=1559388656971&repos=deb-nightly")
        assertThat(searchRequest.headers.get("Authorization"))
                .isEqualTo(Credentials.basic("aUser", "aKey"))

        RecordedRequest firstDeleteRequest = this.mws.takeRequest()

        assertThat(firstDeleteRequest.path)
                .isEqualTo("/deb-nightly/pool/main/a/adoptopenjdk-11-hotspot/adoptopenjdk-11-hotspot_11.0.3+7-201905151809-1_amd64.deb")
        assertThat(firstDeleteRequest.headers.get("Authorization"))
                .isEqualTo(Credentials.basic("aUser", "aKey"))

        RecordedRequest secondDeleteRequest = this.mws.takeRequest()

        assertThat(secondDeleteRequest.path)
                .isEqualTo("/deb-nightly/pool/main/a/adoptopenjdk-11-hotspot/adoptopenjdk-11-hotspot_11.0.3+7-201905151811-1_ppc64el.deb")
        assertThat(secondDeleteRequest.headers.get("Authorization"))
                .isEqualTo(Credentials.basic("aUser", "aKey"))

        assertThat(result.task(":removeDebianNightlyBuilds").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }

    @Test
    void rpmPackagesRemovedThatAreOlderThanOneDay() {
        String searchResponseBody = """
            {
              "results" : [ {
                "uri" : "https://example.com/api/storage/rpm-nightly/centos/6/x86_64/Packages/adoptopenjdk-12-hotspot-12.0.1+12-1.x86_64.rpm",
                "created" : "2019-05-19T10:41:51.142Z"
              }, {
                "uri" : "https://example.com/api/storage/rpm-nightly/centos/6/x86_64/repodata/repomd.xml",
                "created" : "2019-05-19T10:41:51.660Z"
              }, {
                "uri" : "https://example.com/api/storage/rpm-nightly/centos/6/x86_64/repodata/repomd.xml.asc",
                "created" : "2019-05-19T10:41:51.929Z"
              }, {
                "uri" : "https://example.com/api/storage/rpm-nightly/centos/6/x86_64/repodata/repomd.xml.key",
                "created" : "2019-05-19T10:41:51.950Z"
              }, {
                "uri" : "https://example.com/api/storage/rpm-nightly/centos/7/x86_64/Packages/adoptopenjdk-12-hotspot-12.0.1+12-1.x86_64.rpm",
                "created" : "2019-05-19T10:41:52.314Z"
              } ]
            }
        """
        MockResponse searchResponse = new MockResponse()
                .setResponseCode(200)
                .setBody(searchResponseBody)

        this.mws.enqueue(searchResponse)

        MockResponse deleteResponse = new MockResponse()
                .setResponseCode(204)

        // Two rpm packages should be deleted
        this.mws.enqueue(deleteResponse)
        this.mws.enqueue(deleteResponse)

        settingsFile << "rootProject.name = 'rpm'"
        buildFile << """
            plugins {
                id "net.adoptopenjdk.installer"
            }

            import java.time.Instant
            import java.time.ZoneId
            tasks.register("removeRpmNightlyBuilds", net.adoptopenjdk.installer.RemoveObsoletePackages) {
                apiEndpoint = "${this.mws.url("/")}"
                user = "aUser"
                password = "aKey"
                repository = "rpm-nightly"
                daysToKeep = 1
                clock = Clock.fixed(Instant.ofEpochMilli(1559994459882), ZoneId.of("UTC"))
            }
        """

        def result = GradleRunner.create()
                .withProjectDir(tempProjectDir)
                .withArguments("removeRpmNightlyBuilds")
                .withPluginClasspath()
                .build()

        assertThat(this.mws.requestCount).isEqualTo(3)

        RecordedRequest searchRequest = this.mws.takeRequest()

        assertThat(searchRequest.path)
                .isEqualTo("/api/search/creation?from=0&to=1559908059882&repos=rpm-nightly")
        assertThat(searchRequest.headers.get("Authorization"))
                .isEqualTo(Credentials.basic("aUser", "aKey"))

        RecordedRequest firstDeleteRequest = this.mws.takeRequest()

        assertThat(firstDeleteRequest.path)
                .isEqualTo("/rpm-nightly/centos/6/x86_64/Packages/adoptopenjdk-12-hotspot-12.0.1+12-1.x86_64.rpm")
        assertThat(firstDeleteRequest.headers.get("Authorization"))
                .isEqualTo(Credentials.basic("aUser", "aKey"))

        RecordedRequest secondDeleteRequest = this.mws.takeRequest()

        assertThat(secondDeleteRequest.path)
                .isEqualTo("/rpm-nightly/centos/7/x86_64/Packages/adoptopenjdk-12-hotspot-12.0.1+12-1.x86_64.rpm")
        assertThat(secondDeleteRequest.headers.get("Authorization"))
                .isEqualTo(Credentials.basic("aUser", "aKey"))

        assertThat(result.task(":removeRpmNightlyBuilds").outcome).isEqualTo(TaskOutcome.SUCCESS)
    }
}
