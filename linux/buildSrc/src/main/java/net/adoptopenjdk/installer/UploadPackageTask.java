package net.adoptopenjdk.installer;

import org.jfrog.artifactory.client.Artifactory;
import org.jfrog.artifactory.client.ArtifactoryClientBuilder;

import javax.inject.Inject;

class UploadPackageTask implements Runnable {

    private final String url;

    private final ArtifactoryCredentials credentials;

    private final PackageUpload packageUpload;

    @Inject
    UploadPackageTask(String url, ArtifactoryCredentials credentials, PackageUpload upload) {
        this.url = url;
        this.credentials = credentials;
        this.packageUpload = upload;
    }

    @Override
    public void run() {
        Artifactory artifactory = ArtifactoryClientBuilder.create()
                .setUrl(url)
                .setUsername(credentials.getUser())
                .setPassword(credentials.getPassword())
                .build();

        if (packageUpload instanceof DebianPackageUpload) {
            artifactory.repository(packageUpload.getRepository())
                    .upload(packageUpload.getRemotePath(), packageUpload.getFile())
                    .withProperty("deb.distribution",
                            ((DebianPackageUpload) packageUpload).getDistributions().toArray())
                    .withProperty("deb.component",
                            ((DebianPackageUpload) packageUpload).getComponents().toArray())
                    .withProperty("deb.architecture",
                            ((DebianPackageUpload) packageUpload).getArchitectures().toArray())
                    .bySha1Checksum()
                    .doUpload();
        } else {
            artifactory.repository(packageUpload.getRepository())
                    .upload(packageUpload.getRemotePath(), packageUpload.getFile())
                    .bySha1Checksum()
                    .doUpload();
        }
    }
}
