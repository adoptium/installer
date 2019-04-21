package net.adoptopenjdk.installer.bintray;

import com.squareup.moshi.FromJson;
import com.squareup.moshi.ToJson;

import java.util.ArrayList;

class CreatePackageMoshiAdapter {
    @FromJson
    CreatePackage createPackageFromJson(CreatePackageJson createPackageJson) {
        throw new UnsupportedOperationException("Not implemented yet");
    }

    @ToJson
    CreatePackageJson createPackageToJson(CreatePackage createPackage) {
        CreatePackageJson json = new CreatePackageJson();
        json.name = createPackage.getName();
        json.desc = createPackage.getDescription();
        json.licenses = new ArrayList<>(createPackage.getLicenses());
        json.vcs_url = createPackage.getVcsUrl();
        json.website_url = createPackage.getWebsiteUrl();
        return json;
    }
}
