package net.adoptopenjdk.installer.bintray;

import com.squareup.moshi.JsonAdapter;
import com.squareup.moshi.Moshi;
import okhttp3.mockwebserver.MockResponse;
import okhttp3.mockwebserver.MockWebServer;
import okhttp3.mockwebserver.RecordedRequest;
import okio.BufferedSink;
import okio.Okio;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.io.File;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.SortedSet;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class BintrayClientTest {

    private final BintrayCredentials bintrayCredentials = new BintrayCredentials("user", "key");

    private final Moshi moshi = new Moshi.Builder()
            .build();

    private File fileToUpload;

    private MockWebServer mws;

    private BintrayClient bintrayClient;

    @BeforeEach
    void setUp() throws Exception {
        this.fileToUpload = Files.createTempFile(null, null).toFile();
        try (BufferedSink sink = Okio.buffer(Okio.sink(this.fileToUpload))) {
            sink.writeUtf8("Some text");
        }

        this.mws = new MockWebServer();
        this.bintrayClient = new BintrayClient(mws.url("/").toString(), bintrayCredentials);
    }

    @AfterEach
    void tearDown() throws Exception {
        if (this.fileToUpload != null && this.fileToUpload.exists()) {
            this.fileToUpload.delete();
        }

        this.mws.shutdown();
    }

    @Test
    void packageCreationIsSuccessful() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(201);

        this.mws.enqueue(mockResponse);

        CreatePackage createPackage = new CreatePackage.Builder()
                .subject("aSubject")
                .repository("aRepository")
                .name("aPackage")
                .description("Some description")
                .licenses("GPL-2.0+CE")
                .vcsUrl("https://example.com/vcs")
                .websiteUrl("https://www.example.com/")
                .build();

        this.bintrayClient.createPackage(createPackage);

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualTo("POST");
        assertThat(recordedRequest.getPath()).isEqualTo("/packages/aSubject/aRepository");
        assertThat(recordedRequest.getHeader("Content-Type")).isEqualTo("application/json; charset=utf-8");

        JsonAdapter<CreatePackageJson> createPackageJsonAdapter = moshi.adapter(CreatePackageJson.class);
        CreatePackageJson sentJson = createPackageJsonAdapter.fromJson(recordedRequest.getBody());

        assertThat(sentJson.name).isEqualTo("aPackage");
        assertThat(sentJson.desc).isEqualTo("Some description");
        assertThat(sentJson.licenses).containsExactly("GPL-2.0+CE");
        assertThat(sentJson.vcs_url).isEqualTo("https://example.com/vcs");
        assertThat(sentJson.website_url).isEqualTo("https://www.example.com/");
    }

    @Test
    void packageCreationErrorResultsInException() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(409)
                .setBody("{\"message\": \"conflict\"}");

        this.mws.enqueue(mockResponse);

        CreatePackage createPackage = new CreatePackage.Builder()
                .subject("aSubject")
                .repository("aRepository")
                .name("aPackage")
                .description("Some description")
                .licenses("GPL-2.0+CE")
                .vcsUrl("https://example.com/vcs")
                .websiteUrl("https://www.example.com/")
                .build();

        assertThatThrownBy(() -> this.bintrayClient.createPackage(createPackage))
                .isInstanceOf(BintrayClientException.class)
                .hasMessage("Could not create package: conflict");

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualTo("POST");
        assertThat(recordedRequest.getPath()).isEqualTo("/packages/aSubject/aRepository");
        assertThat(recordedRequest.getHeader("Content-Type")).isEqualTo("application/json; charset=utf-8");

        JsonAdapter<CreatePackageJson> createPackageJsonAdapter = moshi.adapter(CreatePackageJson.class);
        CreatePackageJson sentJson = createPackageJsonAdapter.fromJson(recordedRequest.getBody());

        assertThat(sentJson.name).isEqualTo("aPackage");
        assertThat(sentJson.desc).isEqualTo("Some description");
        assertThat(sentJson.licenses).containsExactly("GPL-2.0+CE");
        assertThat(sentJson.vcs_url).isEqualTo("https://example.com/vcs");
        assertThat(sentJson.website_url).isEqualTo("https://www.example.com/");
    }

    @Test
    void packageUpdateIsSuccessful() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(200);

        this.mws.enqueue(mockResponse);

        UpdatePackage updatePackage = new UpdatePackage.Builder()
                .subject("aSubject")
                .repository("aRepository")
                .name("aPackage")
                .description("Some description")
                .licenses("GPL-2.0+CE")
                .vcsUrl("https://example.com/vcs")
                .websiteUrl("https://www.example.com/")
                .build();

        this.bintrayClient.updatePackage(updatePackage);

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualTo("PATCH");
        assertThat(recordedRequest.getPath()).isEqualTo("/packages/aSubject/aRepository/aPackage");
        assertThat(recordedRequest.getHeader("Content-Type")).isEqualTo("application/json; charset=utf-8");

        JsonAdapter<UpdatePackageJson> createPackageJsonAdapter = moshi.adapter(UpdatePackageJson.class);
        UpdatePackageJson sentJson = createPackageJsonAdapter.fromJson(recordedRequest.getBody());

        assertThat(sentJson.desc).isEqualTo("Some description");
        assertThat(sentJson.licenses).containsExactly("GPL-2.0+CE");
        assertThat(sentJson.vcs_url).isEqualTo("https://example.com/vcs");
        assertThat(sentJson.website_url).isEqualTo("https://www.example.com/");
    }

    @Test
    void packageUpdateErrorResultsInException() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(409)
                .setBody("{\"message\": \"conflict\"}");

        this.mws.enqueue(mockResponse);

        UpdatePackage updatePackage = new UpdatePackage.Builder()
                .subject("aSubject")
                .repository("aRepository")
                .name("aPackage")
                .description("Some description")
                .licenses("GPL-2.0+CE")
                .vcsUrl("https://example.com/vcs")
                .websiteUrl("https://www.example.com/")
                .build();

        assertThatThrownBy(() -> this.bintrayClient.updatePackage(updatePackage))
                .isInstanceOf(BintrayClientException.class)
                .hasMessage("Could not update package: conflict");

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualTo("PATCH");
        assertThat(recordedRequest.getPath()).isEqualTo("/packages/aSubject/aRepository/aPackage");
        assertThat(recordedRequest.getHeader("Content-Type")).isEqualTo("application/json; charset=utf-8");

        JsonAdapter<UpdatePackageJson> createPackageJsonAdapter = moshi.adapter(UpdatePackageJson.class);
        UpdatePackageJson sentJson = createPackageJsonAdapter.fromJson(recordedRequest.getBody());

        assertThat(sentJson.desc).isEqualTo("Some description");
        assertThat(sentJson.licenses).containsExactly("GPL-2.0+CE");
        assertThat(sentJson.vcs_url).isEqualTo("https://example.com/vcs");
        assertThat(sentJson.website_url).isEqualTo("https://www.example.com/");
    }

    @Test
    void packageUploadEncodesRemotePathComponents() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}");

        this.mws.enqueue(mockResponse);

        PackageUpload upload = new PackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("äSubject")
                .repository("testRepö")
                .name("packageNamë")
                .version("1.0.0-bø")
                .remotePath("/söme/remøte/påth/")
                .build();

        this.bintrayClient.uploadPackage(upload);

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualToIgnoringCase("PUT");
        assertThat(recordedRequest.getPath()).isEqualTo(
                "/content/%C3%A4Subject/testRep%C3%B6/packageNam%C3%AB/1.0.0-b%C3%B8/s%C3%B6me/rem%C3%B8te/p%C3%A5th/"
        );
        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="))
                .containsEntry("X-Bintray-Publish", Collections.singletonList("0"));
        assertThat(recordedRequest.getBody().readString(StandardCharsets.UTF_8))
                .isEqualTo("Some text");
    }

    @Test
    void packageUploadAutoPublishIsOffByDefault() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}");

        this.mws.enqueue(mockResponse);

        PackageUpload upload = new PackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("aSubject")
                .repository("testRepo")
                .name("packageName")
                .version("1.0.0-b01")
                .remotePath("/some/remote/path/")
                .build();

        this.bintrayClient.uploadPackage(upload);

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualToIgnoringCase("PUT");
        assertThat(recordedRequest.getPath())
                .isEqualTo("/content/aSubject/testRepo/packageName/1.0.0-b01/some/remote/path/");
        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="))
                .containsEntry("X-Bintray-Publish", Collections.singletonList("0"))
                .doesNotContainKey("X-Bintray-Debian-Distribution")
                .doesNotContainKey("X-Bintray-Debian-Component")
                .doesNotContainKey("X-Bintray-Debian-Architecture");
        assertThat(recordedRequest.getBody().readString(StandardCharsets.UTF_8))
                .isEqualTo("Some text");
    }

    @Test
    void packageUploadAutoPublishIsOnIfConfigured() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}");

        this.mws.enqueue(mockResponse);

        PackageUpload upload = new PackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("aSubject")
                .repository("testRepo")
                .name("packageName")
                .version("1.0.0-b01")
                .remotePath("/some/remote/path/")
                .autoPublish(true)
                .build();

        this.bintrayClient.uploadPackage(upload);

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualToIgnoringCase("PUT");
        assertThat(recordedRequest.getPath())
                .isEqualTo("/content/aSubject/testRepo/packageName/1.0.0-b01/some/remote/path/");
        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="))
                .containsEntry("X-Bintray-Publish", Collections.singletonList("1"));
        assertThat(recordedRequest.getBody().readString(StandardCharsets.UTF_8))
                .isEqualTo("Some text");
    }

    @Test
    void packageUploadWithErrorResponseCausesException() {
        this.mws.enqueue(new MockResponse().setResponseCode(500));

        PackageUpload upload = new PackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("aSubject")
                .repository("testRepo")
                .name("packageName")
                .version("1.0.0-b01")
                .remotePath("/some/remote/path/")
                .build();

        assertThatThrownBy(() -> this.bintrayClient.uploadPackage(upload))
                .isInstanceOf(BintrayClientException.class)
                .hasMessage("Package upload failed");
    }

    @Test
    void packageUploadOtherMessageThanSuccessCausesException() {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("{\"message\": \"something\"}");

        this.mws.enqueue(mockResponse);

        PackageUpload upload = new PackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("aSubject")
                .repository("testRepo")
                .name("packageName")
                .version("1.0.0-b01")
                .remotePath("/some/remote/path/")
                .build();

        assertThatThrownBy(() -> this.bintrayClient.uploadPackage(upload))
                .isInstanceOf(BintrayClientException.class)
                .hasMessage("Package upload failed: something");
    }

    @Test
    void packageUploadWithoutMessageCausesException() {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("{\"foo\": \"something\"}");

        this.mws.enqueue(mockResponse);

        PackageUpload upload = new PackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("aSubject")
                .repository("testRepo")
                .name("packageName")
                .version("1.0.0-b01")
                .remotePath("/some/remote/path/")
                .build();

        assertThatThrownBy(() -> this.bintrayClient.uploadPackage(upload))
                .isInstanceOf(BintrayClientException.class)
                .hasMessage("Package upload failed: null");
    }

    @Test
    void debianPackageUploadIncludesDebianSpecificProperties() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(201)
                .setBody("{\"message\": \"success\"}");
        this.mws.enqueue(mockResponse);

        Set<String> distributions = new LinkedHashSet<>();
        distributions.add("xenial");
        distributions.add("bionic");

        Set<String> components = new LinkedHashSet<>();
        components.add("main");
        components.add("extra");

        Set<String> architectures = new LinkedHashSet<>();
        architectures.add("s390x");
        architectures.add("amd64");

        DebianPackageUpload upload = new DebianPackageUpload.Builder()
                .file(this.fileToUpload)
                .subject("aSubject")
                .repository("testRepo")
                .name("packageName")
                .version("1.0.0-b01")
                .remotePath("/some/remote/path/")
                .distributions(distributions)
                .components(components)
                .architectures(architectures)
                .build();

        this.bintrayClient.uploadPackage(upload);

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getMethod()).isEqualToIgnoringCase("PUT");
        assertThat(recordedRequest.getPath())
                .isEqualTo("/content/aSubject/testRepo/packageName/1.0.0-b01/some/remote/path/");
        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="))
                .containsEntry("X-Bintray-Publish", Collections.singletonList("0"))
                .containsEntry("X-Bintray-Debian-Distribution", Collections.singletonList("xenial,bionic"))
                .containsEntry("X-Bintray-Debian-Component", Collections.singletonList("main,extra"))
                .containsEntry("X-Bintray-Debian-Architecture", Collections.singletonList("s390x,amd64"));
        assertThat(recordedRequest.getBody().readString(StandardCharsets.UTF_8))
                .isEqualTo("Some text");
    }

    @Test
    void packageListReturnedInAlphabeticalOrder() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"two\",\"linked\":false},{\"name\":\"one\",\"linked\":false}]");

        this.mws.enqueue(mockResponse);

        SortedSet<String> packages = this.bintrayClient.getPackages("aSubject", "aRepository");

        assertThat(packages).containsExactly("one", "two");

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="));
        assertThat(recordedRequest.getPath()).isEqualTo("/repos/aSubject/aRepository/packages");
    }

    @Test
    void packageListIsEmptyWhenPackageIndexIsEmpty() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[]");

        this.mws.enqueue(mockResponse);

        SortedSet<String> packages = this.bintrayClient.getPackages("aSubject", "aRepository");

        assertThat(packages).isEmpty();

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="));
        assertThat(recordedRequest.getPath()).isEqualTo("/repos/aSubject/aRepository/packages");
    }

    @Test
    void packageListThrowsExceptionIfErrorMessageIsReturned() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(404)
                .setBody("{\"message\":\"Subject 'doesNotExist' was not found\"}");

        this.mws.enqueue(mockResponse);

        assertThatThrownBy(() -> this.bintrayClient.getPackages("aSubject", "aRepository"))
                .isInstanceOf(BintrayClientException.class)
                .hasMessage("Could not obtain list of packages: Subject 'doesNotExist' was not found");

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="));
        assertThat(recordedRequest.getPath()).isEqualTo("/repos/aSubject/aRepository/packages");
    }

    @Test
    void packageExistsIfItIsListedInPackageIndex() throws Exception {
        MockResponse mockResponse = new MockResponse()
                .setResponseCode(200)
                .setBody("[{\"name\":\"two\",\"linked\":false},{\"name\":\"one\",\"linked\":false}]");

        this.mws.enqueue(mockResponse);

        boolean exists = this.bintrayClient.packageExists("aSubject", "aRepository", "one");

        assertThat(exists)
                .overridingErrorMessage("Package should exist but does not")
                .isTrue();

        RecordedRequest recordedRequest = this.mws.takeRequest();

        assertThat(recordedRequest.getHeaders().toMultimap())
                .containsEntry("Authorization", Collections.singletonList("Basic dXNlcjprZXk="));
        assertThat(recordedRequest.getPath()).isEqualTo("/repos/aSubject/aRepository/packages");
    }
}
