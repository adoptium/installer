package net.adoptopenjdk.installer;

import org.jfrog.artifactory.client.model.RepoPath;

import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;

public class UploadDebianPackage extends AbstractUploadLinuxPackage {

    public UploadDebianPackage() {
        setGroup("upload");
        setDescription("Uploads a Debian package");
    }

    @Override
    protected void uploadPackages() {
        Set<String> distributionsToPublish = distributions();
        if (distributionsToPublish.isEmpty()) {
            return;
        }

        // We must not overwrite an existing artifact. But because all
        // distributions share the same file in Artifactory, we might need to
        // update the package's metadata with a new set of supported
        // distributions.
        if (this.artifactExists()) {
            getLogger().lifecycle(
                    "Setting supported distributions of {} in {} to {} on {}",
                    getPackageToPublish().getName(),
                    getRepository(),
                    distributions(),
                    getArchitecture()
            );

            this.updateSupportedDistributions();
            return;
        }

        DebianPackageUpload upload = new DebianPackageUpload.Builder()
                .file(getPackageToPublish())
                .repository(getRepository())
                .remotePath(targetFilePath())
                .distributions(distributionsToPublish)
                .components(Collections.singleton("main"))
                .architectures(Collections.singleton(getArchitecture()))
                .build();

        getLogger().lifecycle(
                "Uploading {} to {} for {} on {}",
                getPackageToPublish().getName(),
                getRepository(),
                distributions(),
                getArchitecture()
        );

        this.getArtifactoryClient()
                .repository(upload.getRepository())
                .upload(upload.getRemotePath(), upload.getFile())
                .withProperty("deb.distribution", upload.getDistributions().toArray())
                .withProperty("deb.component", upload.getComponents().toArray())
                .withProperty("deb.architecture", upload.getArchitectures().toArray())
                .bySha1Checksum()
                .doUpload();
    }

    private boolean artifactExists() {
        List<RepoPath> searchResults = this.getArtifactoryClient()
                .searches()
                .repositories(getRepository())
                .artifactsByName(getPackageToPublish().getName())
                .doSearch();

        if (searchResults.isEmpty()) {
            return false;
        }

        for (RepoPath searchResult : searchResults) {
            if (Objects.equals(getRepository(), searchResult.getRepoKey())
                    && Objects.equals(this.targetFilePath(), searchResult.getItemPath())) {
                return true;
            }
        }

        return false;
    }

    private void updateSupportedDistributions() {
        this.getArtifactoryClient()
                .repository(this.getRepository())
                .file(targetFilePath())
                .properties()
                .addProperty("deb.distribution", distributions().toArray(new String[0]))
                .doSet();
    }

    private String targetFilePath() {
        return String.format("pool/main/%s/%s/%s", getPackageName().substring(0, 1).toLowerCase(Locale.US),
                getPackageName(), getPackageToPublish().getName());
    }

    private Set<String> distributions() {
        Set<String> distributions = new LinkedHashSet<>();
        if (getReleaseArchitectures().containsKey(getArchitecture())) {
            for (List<String> distributionVersions : getReleaseArchitectures().get(getArchitecture()).values()) {
                distributions.addAll(distributionVersions);
            }
        }
        return distributions;
    }
}
