package net.adoptopenjdk.installer;

import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.InputFile;
import org.gradle.api.tasks.Optional;
import org.gradle.api.tasks.TaskAction;

import java.io.File;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public abstract class AbstractUploadLinuxPackage extends DefaultTask {

    private File packageToPublish;

    private String apiEndpoint = "https://adoptopenjdk.jfrog.io/artifactory";

    private String user;

    private String password;

    private String repository;

    private String packageName;

    private String architecture;

    private Map<String, Map<String, List<String>>> releaseArchitectures = new LinkedHashMap<>();

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
    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
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

    @TaskAction
    public final void exec() {
        ArtifactoryCredentials credentials = new ArtifactoryCredentials(getUser(), getPassword());
        uploadPackages(credentials);
    }

    protected abstract void uploadPackages(ArtifactoryCredentials artifactoryCredentials);
}
