package net.adoptopenjdk.installer.bintray;

import com.squareup.moshi.JsonAdapter;
import com.squareup.moshi.Moshi;
import com.squareup.moshi.Types;
import okhttp3.Credentials;
import okhttp3.HttpUrl;
import okhttp3.MediaType;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.RequestBody;
import okhttp3.Response;

import java.io.IOException;
import java.io.UncheckedIOException;
import java.lang.reflect.Type;
import java.time.Duration;
import java.util.List;
import java.util.SortedSet;
import java.util.TreeSet;
import java.util.stream.Collectors;

public class BintrayClient {

    private final HttpUrl endpoint;

    private final BintrayCredentials credentials;

    private final OkHttpClient client;

    private final Moshi moshi = new Moshi.Builder()
            .add(new CreatePackageMoshiAdapter())
            .add(new UpdatePackageMoshiAdapter())
            .build();

    public BintrayClient(BintrayCredentials credentials) {
        this("https://api.bintray.com", credentials);
    }

    public BintrayClient(String endpoint, BintrayCredentials credentials) {
        this(endpoint, credentials, Duration.ofMinutes(10));
    }

    public BintrayClient(String endpoint, BintrayCredentials credentials, Duration uploadTimeout) {
        this.endpoint = HttpUrl.parse(endpoint);
        this.credentials = credentials;

        this.client = new OkHttpClient.Builder()
                .readTimeout(uploadTimeout)
                .build();
    }

    public void createPackage(CreatePackage createPackage) {
        HttpUrl targetUrl = this.endpoint.newBuilder()
                .addPathSegment("packages")
                .addPathSegment(createPackage.getSubject())
                .addPathSegment(createPackage.getRepository())
                .build();

        JsonAdapter<CreatePackage> createPackageAdapter = moshi.adapter(CreatePackage.class);
        String json = createPackageAdapter.toJson(createPackage);

        Request request = new Request.Builder()
                .addHeader("Authorization", getBasicCredentials())
                .url(targetUrl)
                .post(RequestBody.create(MediaType.parse("application/json"), json))
                .build();

        try (Response response = this.client.newCall(request).execute()) {
            if (response.body() == null) {
                throw new NullPointerException("Response to package creation is unexpectedly null");
            }

            if (!response.isSuccessful()) {
                JsonAdapter<MessageJson> messageAdapter = moshi.adapter(MessageJson.class);
                MessageJson messageJson = messageAdapter.fromJson(response.body().source());
                throw new BintrayClientException("Could not create package: " + messageJson);
            }
        } catch (IOException e) {
            throw new UncheckedIOException("Could not create package", e);
        }
    }

    public void updatePackage(UpdatePackage updatePackage) {
        HttpUrl targetUrl = this.endpoint.newBuilder()
                .addPathSegment("packages")
                .addPathSegment(updatePackage.getSubject())
                .addPathSegment(updatePackage.getRepository())
                .addPathSegment(updatePackage.getName())
                .build();

        JsonAdapter<UpdatePackage> updatePackageAdapter = moshi.adapter(UpdatePackage.class);
        String json = updatePackageAdapter.toJson(updatePackage);

        Request request = new Request.Builder()
                .addHeader("Authorization", getBasicCredentials())
                .url(targetUrl)
                .patch(RequestBody.create(MediaType.parse("application/json"), json))
                .build();

        try (Response response = this.client.newCall(request).execute()) {
            if (response.body() == null) {
                throw new NullPointerException("Response to package update is unexpectedly null");
            }

            if (!response.isSuccessful()) {
                JsonAdapter<MessageJson> messageAdapter = moshi.adapter(MessageJson.class);
                MessageJson messageJson = messageAdapter.fromJson(response.body().source());
                throw new BintrayClientException("Could not update package: " + messageJson);
            }
        } catch (IOException e) {
            throw new UncheckedIOException("Could not update package", e);
        }
    }

    public void uploadPackage(PackageUpload packageUpload) {
        HttpUrl targetUrl = this.endpoint.newBuilder()
                .addPathSegment("content")
                .addEncodedPathSegment(packageUpload.getSubject())
                .addEncodedPathSegment(packageUpload.getRepository())
                .addEncodedPathSegment(packageUpload.getPackageName())
                .addEncodedPathSegment(packageUpload.getPackageVersion())
                .addPathSegments(packageUpload.getRemotePath())
                .build();

        Request.Builder requestBuilder = new Request.Builder();
        requestBuilder.addHeader("Authorization", getBasicCredentials());
        requestBuilder.addHeader("X-Bintray-Publish", String.valueOf(packageUpload.getAutoPublish()));

        if (packageUpload instanceof DebianPackageUpload) {
            DebianPackageUpload debPkg = (DebianPackageUpload) packageUpload;
            requestBuilder.addHeader("X-Bintray-Debian-Distribution", debPkg.distributionsAsHeader());
            requestBuilder.addHeader("X-Bintray-Debian-Component", debPkg.componentsAsHeader());
            requestBuilder.addHeader("X-Bintray-Debian-Architecture", debPkg.architecturesAsHeader());
        }

        requestBuilder.put(RequestBody.create(MediaType.parse("application/octet-stream"), packageUpload.getFile()));
        requestBuilder.url(targetUrl);

        try (Response response = client.newCall(requestBuilder.build()).execute()) {
            if (response.body() == null) {
                throw new NullPointerException("Response to package upload is unexpectedly null");
            }
            JsonAdapter<MessageJson> messageAdapter = moshi.adapter(MessageJson.class);
            MessageJson messageJson = messageAdapter.fromJson(response.body().source());

            if (!response.isSuccessful() || messageJson == null || !"success".equalsIgnoreCase(messageJson.message)) {
                throw new BintrayClientException("Package upload failed: " + messageJson);
            }
        } catch (IOException e) {
            throw new BintrayClientException("Package upload failed", e);
        }
    }

    public SortedSet<String> getPackages(String subject, String repository) {
        HttpUrl apiUrl = this.endpoint.newBuilder()
                .addPathSegment("repos")
                .addPathSegment(subject)
                .addPathSegment(repository)
                .addPathSegment("packages")
                .build();

        Request request = new Request.Builder()
                .addHeader("Authorization",
                        getBasicCredentials())
                .url(apiUrl)
                .build();

        try (Response response = this.client.newCall(request).execute()) {
            if (!response.isSuccessful()) {
                if (response.body() == null) {
                    throw new NullPointerException("Response body is unexpectedly null");
                }
                JsonAdapter<MessageJson> messageAdapter = moshi.adapter(MessageJson.class);
                MessageJson messageJson = messageAdapter.fromJson(response.body().string());
                throw new BintrayClientException("Could not obtain list of packages: " + messageJson);
            }
            if (response.body() == null) {
                throw new NullPointerException("Response body is unexpectedly null");
            }

            Type type = Types.newParameterizedType(List.class, PackageIndexEntryJson.class);
            JsonAdapter<List<PackageIndexEntryJson>> adapter = moshi.adapter(type);
            List<PackageIndexEntryJson> packageIndex = adapter.fromJson(response.body().string());

            if (packageIndex == null) {
                throw new NullPointerException("Package index is unexpectedly null");
            }

            return packageIndex
                    .stream()
                    .map(PackageIndexEntryJson::getName)
                    .collect(Collectors.toCollection(TreeSet::new));
        } catch (IOException e) {
            throw new UncheckedIOException("Could not obtain list of packages", e);
        }
    }

    public boolean packageExists(String subject, String repository, String packageName) {
        return this.getPackages(subject, repository).contains(packageName);
    }

    private String getBasicCredentials() {
        return Credentials.basic(this.credentials.getUser(), this.credentials.getKey());
    }
}
