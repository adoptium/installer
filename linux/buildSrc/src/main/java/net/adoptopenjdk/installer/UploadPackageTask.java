package net.adoptopenjdk.installer;

import net.adoptopenjdk.installer.bintray.BintrayClient;
import net.adoptopenjdk.installer.bintray.BintrayCredentials;
import net.adoptopenjdk.installer.bintray.PackageUpload;

import javax.inject.Inject;

class UploadPackageTask implements Runnable {

    private final String apiEndpoint;

    private final BintrayCredentials bintrayCredentials;

    private final PackageUpload packageUpload;

    @Inject
    UploadPackageTask(String apiEndpoint, BintrayCredentials bintrayCredentials, PackageUpload upload) {
        this.apiEndpoint = apiEndpoint;
        this.packageUpload = upload;
        this.bintrayCredentials = bintrayCredentials;
    }

    @Override
    public void run() {
        BintrayClient client = new BintrayClient(apiEndpoint, bintrayCredentials);
        client.uploadPackage(packageUpload);
    }
}
