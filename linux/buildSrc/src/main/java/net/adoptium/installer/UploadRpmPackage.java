package net.adoptium.installer;

import org.jfrog.artifactory.client.model.RepoPath;

import javax.inject.Inject;
import java.util.List;
import java.util.Map;
import java.util.Objects;

public class UploadRpmPackage extends AbstractUploadLinuxPackage {

    @Inject
    public UploadRpmPackage() {
        setGroup("upload");
        setDescription("Uploads a RPM package");
    }

    @Override
    protected void uploadPackages() {
        if (!getReleaseArchitectures().containsKey(getArchitecture())) {
            return;
        }

        Map<String, List<String>> distributionsForArchitecture = getReleaseArchitectures().get(getArchitecture());
        for (Map.Entry<String, List<String>> distribution : distributionsForArchitecture.entrySet()) {
            for (String version : distribution.getValue()) {
                String remotePath = this.remotePath(
                        distribution.getKey(),
                        version,
                        getArchitecture(),
                        getPackageToPublish().getName()
                );

                // We must not overwrite existing artifacts.
                if (this.artifactExists(remotePath)) {
                    getLogger().warn(
                            "Artifact {} already exists in {} for {}:{} on {}, skipping.",
                            getPackageToPublish().getName(),
                            getRepository(),
                            distribution.getKey(),
                            version,
                            getArchitecture()
                    );
                    continue;
                }

                PackageUpload upload = new PackageUpload.Builder()
                        .file(getPackageToPublish())
                        .repository(getRepository())
                        .remotePath(remotePath)
                        .build();

                getLogger().lifecycle(
                        "Uploading {} to {} for {}:{} on {}",
                        getPackageToPublish().getName(),
                        getRepository(),
                        distribution.getKey(),
                        version,
                        getArchitecture()
                );

                this.getArtifactoryClient()
                        .repository(upload.getRepository())
                        .upload(upload.getRemotePath(), upload.getFile())
                        .bySha1Checksum()
                        .doUpload();
            }
        }
    }

    private boolean artifactExists(String remotePath) {
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
                    && Objects.equals(remotePath.substring(1), searchResult.getItemPath())) {
                return true;
            }
        }

        return false;
    }


    private String remotePath(String distribution, String version, String architecture, String packageFileName) {
        return String.format("/%s/%s/%s/Packages/%s", distribution, version, architecture, packageFileName);
    }
}
