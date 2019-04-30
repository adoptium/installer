package net.adoptopenjdk.installer.bintray;

import java.io.File;
import java.io.Serializable;

public class PackageUpload implements Serializable {

    private final File file;

    private final String subject;

    private final String repository;

    private final String packageName;

    private final String packageVersion;

    private final String remotePath;

    private final boolean autoPublish;

    PackageUpload(
            File file,
            String subject,
            String repository,
            String packageName,
            String packageVersion,
            String remotePath,
            boolean autoPublish
    ) {
        this.file = file;
        this.subject = subject;
        this.repository = repository;
        this.packageName = packageName;
        this.packageVersion = packageVersion;
        this.remotePath = remotePath;
        this.autoPublish = autoPublish;
    }

    public File getFile() {
        return file;
    }

    public String getSubject() {
        return subject;
    }

    public String getRepository() {
        return repository;
    }

    public String getPackageName() {
        return packageName;
    }

    public String getPackageVersion() {
        return packageVersion;
    }

    public String getRemotePath() {
        return remotePath;
    }

    public int getAutoPublish() {
        if (autoPublish) {
            return 1;
        } else {
            return 0;
        }
    }

    public static class Builder extends AbstractPackageUploadBuilder<PackageUpload.Builder> {
        @Override
        public PackageUpload build() {
            return new PackageUpload(file, subject, repository, name, version, remotePath, autoPublish);
        }
    }
}
