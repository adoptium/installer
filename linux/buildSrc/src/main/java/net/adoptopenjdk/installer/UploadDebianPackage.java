package net.adoptopenjdk.installer;

import org.gradle.workers.IsolationMode;
import org.gradle.workers.WorkerExecutor;

import javax.inject.Inject;
import java.util.Collections;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

public class UploadDebianPackage extends AbstractUploadLinuxPackage {

    private final WorkerExecutor executor;

    @Inject
    public UploadDebianPackage(WorkerExecutor executor) {
        this.executor = executor;

        setGroup("upload");
        setDescription("Uploads a Debian package");
    }

    @Override
    protected void uploadPackages(ArtifactoryCredentials artifactoryCredentials) {
        Set<String> distributionsToPublish = distributions();
        if (distributionsToPublish.isEmpty()) {
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

        executor.submit(UploadPackageTask.class, workerConfiguration -> {
            workerConfiguration.setIsolationMode(IsolationMode.NONE);
            workerConfiguration.setParams(getApiEndpoint(), artifactoryCredentials, upload);
        });
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
