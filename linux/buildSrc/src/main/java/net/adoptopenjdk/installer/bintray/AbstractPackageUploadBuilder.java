package net.adoptopenjdk.installer.bintray;

import java.io.File;

public abstract class AbstractPackageUploadBuilder<B extends AbstractPackageUploadBuilder<B>> {
    File file;
    String subject;
    String repository;
    String name;
    String version;
    String remotePath;
    boolean autoPublish = false;

    public B file(File file) {
        this.file = file;
        return self();
    }

    public B subject(String subject) {
        this.subject = subject;
        return self();
    }

    public B repository(String repository) {
        this.repository = repository;
        return self();
    }

    public B name(String name) {
        this.name = name;
        return self();
    }

    public B version(String version) {
        this.version = version;
        return self();
    }

    public B remotePath(String remotePath) {
        if (remotePath.indexOf('/') == 0) {
            remotePath = remotePath.substring(1);
        }

        this.remotePath = remotePath;
        return self();
    }

    public B autoPublish(boolean autoPublish) {
        this.autoPublish = autoPublish;
        return self();
    }

    public abstract PackageUpload build();

    @SuppressWarnings("unchecked")
    final B self() {
        return (B) this;
    }
}
