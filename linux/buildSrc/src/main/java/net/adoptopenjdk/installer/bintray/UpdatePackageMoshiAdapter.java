package net.adoptopenjdk.installer.bintray;

import com.squareup.moshi.FromJson;
import com.squareup.moshi.ToJson;

import java.util.ArrayList;

class UpdatePackageMoshiAdapter {
    @FromJson
    UpdatePackage updatePackageFromJson(UpdatePackageJson updatePackageJson) {
        throw new UnsupportedOperationException("Not implemented yet");
    }

    @ToJson
    UpdatePackageJson updatePackageToJson(UpdatePackage updatePackage) {
        UpdatePackageJson json = new UpdatePackageJson();
        json.desc = updatePackage.getDescription();
        json.licenses = new ArrayList<>(updatePackage.getLicenses());
        json.vcs_url = updatePackage.getVcsUrl();
        json.website_url = updatePackage.getWebsiteUrl();
        return json;
    }
}
