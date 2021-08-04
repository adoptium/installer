package net.adoptium.installer;

import java.io.File;
import java.io.Serializable;

class PackageUpload implements Serializable {

    private final File file;

    private final String repository;

    private final String remotePath;

    PackageUpload(File file, String repository, String remotePath) {
        this.file = file;
        this.repository = repository;
        this.remotePath = remotePath;
    }

    public File getFile() {
        return file;
    }

    public String getRepository() {
        return repository;
    }

    public String getRemotePath() {
        return remotePath;
    }

    public static class Builder extends AbstractPackageUploadBuilder<PackageUpload.Builder> {
        @Override
        public PackageUpload build() {
            return new PackageUpload(file, repository, remotePath);
        }
    }
}
