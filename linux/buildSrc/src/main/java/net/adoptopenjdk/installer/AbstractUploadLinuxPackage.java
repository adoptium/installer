package net.adoptopenjdk.installer;

import net.adoptopenjdk.installer.bintray.BintrayClient;
import net.adoptopenjdk.installer.bintray.BintrayCredentials;
import net.adoptopenjdk.installer.bintray.CreatePackage;
import net.adoptopenjdk.installer.bintray.UpdatePackage;
import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.InputFile;
import org.gradle.api.tasks.Optional;
import org.gradle.api.tasks.TaskAction;

import java.io.File;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public abstract class AbstractUploadLinuxPackage extends DefaultTask {

    private File packageToPublish;

    private String apiEndpoint = "https://api.bintray.com/";

    private String user;

    private String key;

    private String subject;

    private String repository;

    private String packageName;

    private String packageVersion;

    private String packageDescription;

    private Set<String> licenses;

    private String websiteUrl;

    private String vcsUrl;

    private String architecture;

    private Map<String, Map<String, List<String>>> releaseArchitectures = new LinkedHashMap<>();

    private boolean autoPublish = false;

    private boolean autoCreatePackage = false;

    private boolean autoUpdatePackage = false;

    @Input
    @Optional
    public String getApiEndpoint() {
        return apiEndpoint;
    }

    public void setApiEndpoint(String apiEndpoint) {
        this.apiEndpoint = apiEndpoint;
    }

    @InputFile
    public File getPackageToPublish() {
        return packageToPublish;
    }

    public void setPackageToPublish(File packageToPublish) {
        this.packageToPublish = packageToPublish;
    }

    @Input
    @Optional
    public String getUser() {
        return user;
    }

    public void setUser(String user) {
        this.user = user;
    }

    @Input
    @Optional
    public String getKey() {
        return key;
    }

    public void setKey(String key) {
        this.key = key;
    }

    @Input
    public String getSubject() {
        return subject;
    }

    public void setSubject(String subject) {
        this.subject = subject;
    }

    @Input
    public String getRepository() {
        return repository;
    }

    public void setRepository(String repository) {
        this.repository = repository;
    }

    @Input
    public String getPackageName() {
        return packageName;
    }

    public void setPackageName(String packageName) {
        this.packageName = packageName;
    }

    @Input
    public String getPackageVersion() {
        return packageVersion;
    }

    public void setPackageVersion(String packageVersion) {
        this.packageVersion = packageVersion;
    }

    @Input
    public String getPackageDescription() {
        return packageDescription;
    }

    public void setPackageDescription(String packageDescription) {
        this.packageDescription = packageDescription;
    }

    @Input
    public Set<String> getLicenses() {
        return licenses;
    }

    public void setLicenses(Set<String> licenses) {
        this.licenses = licenses;
    }

    @Input
    public String getWebsiteUrl() {
        return websiteUrl;
    }

    public void setWebsiteUrl(String websiteUrl) {
        this.websiteUrl = websiteUrl;
    }

    @Input
    public String getVcsUrl() {
        return vcsUrl;
    }

    public void setVcsUrl(String vcsUrl) {
        this.vcsUrl = vcsUrl;
    }

    @Input
    public String getArchitecture() {
        return architecture;
    }

    public void setArchitecture(String architecture) {
        this.architecture = architecture;
    }

    @Input
    public Map<String, Map<String, List<String>>> getReleaseArchitectures() {
        return releaseArchitectures;
    }

    public void setReleaseArchitectures(Map<String, Map<String, List<String>>> releaseArchitectures) {
        this.releaseArchitectures = releaseArchitectures;
    }

    public void releaseArchitecture(Map<String, Map<String, List<String>>> archs) {
        releaseArchitectures.putAll(archs);
    }

    @Input
    @Optional
    public boolean isAutoPublish() {
        return autoPublish;
    }

    public void setAutoPublish(boolean autoPublish) {
        this.autoPublish = autoPublish;
    }

    @Input
    @Optional
    public boolean isAutoCreatePackage() {
        return autoCreatePackage;
    }

    public void setAutoCreatePackage(boolean autoCreatePackage) {
        this.autoCreatePackage = autoCreatePackage;
    }

    @Input
    @Optional
    public boolean isAutoUpdatePackage() {
        return autoUpdatePackage;
    }

    public void setAutoUpdatePackage(boolean autoUpdatePackage) {
        this.autoUpdatePackage = autoUpdatePackage;
    }

    @TaskAction
    public final void exec() {
        BintrayClient bintrayClient = new BintrayClient(getApiEndpoint(), new BintrayCredentials(getUser(), getKey()));

        if (!this.packageExists(bintrayClient)) {
            if (isAutoCreatePackage()) {
                getLogger().lifecycle(
                        "Package {}/{}/{} does not exists, going to create it.",
                        getSubject(),
                        getRepository(),
                        getPackageVersion()
                );

                this.createPackage(bintrayClient);
            } else {
                throw new RuntimeException(String.format(
                        "Package %s/%s/%s does not exists and auto creation is off.",
                        getSubject(),
                        getRepository(),
                        getPackageVersion()
                ));
            }
        } else {
            if (isAutoUpdatePackage()) {
                getLogger().lifecycle(
                        "Updating package {}/{}/{}.",
                        getSubject(),
                        getRepository(),
                        getPackageVersion()
                );

                this.updatePackage(bintrayClient);
            } else {
                getLogger().info(
                        "Skipping update of package {}/{}/{} because auto update is off.",
                        getSubject(),
                        getRepository(),
                        getPackageVersion()
                );
            }
        }

        uploadPackages(bintrayClient);
    }

    protected abstract void uploadPackages(BintrayClient bintrayClient);

    private boolean packageExists(BintrayClient bintrayClient) {
        return bintrayClient.packageExists(getSubject(), getRepository(), getPackageName());
    }

    private void createPackage(BintrayClient bintrayClient) {
        CreatePackage createPackage = new CreatePackage.Builder()
                .subject(getSubject())
                .repository(getRepository())
                .name(getPackageName())
                .description(getPackageDescription())
                .licenses(getLicenses())
                .websiteUrl(getWebsiteUrl())
                .vcsUrl(getVcsUrl())
                .build();
        bintrayClient.createPackage(createPackage);
    }

    private void updatePackage(BintrayClient bintrayClient) {
        UpdatePackage updatePackage = new UpdatePackage.Builder()
                .subject(getSubject())
                .repository(getRepository())
                .name(getPackageName())
                .description(getPackageDescription())
                .licenses(getLicenses())
                .websiteUrl(getWebsiteUrl())
                .vcsUrl(getVcsUrl())
                .build();
        bintrayClient.updatePackage(updatePackage);
    }
}
