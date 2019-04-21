package net.adoptopenjdk.installer;

import net.adoptopenjdk.installer.bintray.BintrayClient;
import net.adoptopenjdk.installer.bintray.BintrayCredentials;
import net.adoptopenjdk.installer.bintray.PackageUpload;
import org.gradle.workers.IsolationMode;
import org.gradle.workers.WorkerExecutor;

import javax.inject.Inject;
import java.util.List;
import java.util.Map;

public class UploadRpmPackage extends AbstractUploadLinuxPackage {

    private final WorkerExecutor executor;

    @Inject
    public UploadRpmPackage(WorkerExecutor executor) {
        this.executor = executor;

        setGroup("upload");
        setDescription("Uploads a RPM package");
    }

    @Override
    protected void uploadPackages(BintrayClient bintrayClient) {
        if (!getReleaseArchitectures().containsKey(getArchitecture())) {
            return;
        }

        Map<String, List<String>> distributionsForArchitecture = getReleaseArchitectures().get(getArchitecture());
        for (Map.Entry<String, List<String>> distribution : distributionsForArchitecture.entrySet()) {
            for (String version : distribution.getValue()) {
                String remotePath = remotePath(
                        distribution.getKey(),
                        version,
                        getArchitecture(),
                        getPackageToPublish().getName()
                );

                PackageUpload upload = new PackageUpload.Builder()
                        .file(getPackageToPublish())
                        .subject(getSubject())
                        .repository(getRepository())
                        .name(getPackageName())
                        .version(getPackageVersion())
                        .remotePath(remotePath)
                        .autoPublish(isAutoPublish())
                        .build();

                getLogger().lifecycle(
                        "Uploading {}, version {} to {}/{}/{} for {}:{} on {}",
                        getPackageToPublish().getName(),
                        getPackageVersion(),
                        getSubject(),
                        getRepository(),
                        getPackageName(),
                        distribution.getKey(),
                        version,
                        getArchitecture()
                );

                executor.submit(UploadPackageTask.class, workerConfig -> {
                    workerConfig.setIsolationMode(IsolationMode.NONE);
                    workerConfig.setParams(getApiEndpoint(), new BintrayCredentials(getUser(), getKey()), upload);
                });
            }
        }
    }

    private String remotePath(String distribution, String version, String architecture, String packageFileName) {
        return String.format("/%s/%s/%s/Packages/%s", distribution, version, architecture, packageFileName);
    }
}
