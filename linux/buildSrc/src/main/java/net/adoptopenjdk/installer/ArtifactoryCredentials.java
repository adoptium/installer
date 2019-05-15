package net.adoptopenjdk.installer;

import java.io.Serializable;

class ArtifactoryCredentials implements Serializable {

    private final String user;

    private final String password;

    ArtifactoryCredentials(String user, String password) {
        this.user = user;
        this.password = password;
    }

    String getUser() {
        return user;
    }

    String getPassword() {
        return password;
    }
}
