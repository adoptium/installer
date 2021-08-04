package net.adoptium.installer;

import java.io.File;

abstract class AbstractPackageUploadBuilder<B extends AbstractPackageUploadBuilder<B>> {

    File file;

    String repository;

    String packageName;

    String remotePath;

    public B file(File file) {
        this.file = file;
        return self();
    }

    public B repository(String repository) {
        this.repository = repository;
        return self();
    }

    public B packageName(String name) {
        this.packageName = name;
        return self();
    }

    public B remotePath(String remotePath) {
        if (remotePath.indexOf('/') == 0) {
            remotePath = remotePath.substring(1);
        }

        this.remotePath = remotePath;
        return self();
    }

    public abstract PackageUpload build();

    @SuppressWarnings("unchecked")
    final B self() {
        return (B) this;
    }
}
