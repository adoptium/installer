package net.adoptopenjdk.installer.bintray;

import java.io.Serializable;
import java.util.StringJoiner;

public class BintrayCredentials implements Serializable {

    private final String user;

    private final String key;

    public BintrayCredentials(String user, String key) {
        this.user = user;
        this.key = key;
    }

    public String getKey() {
        return key;
    }

    public String getUser() {
        return user;
    }

    @Override
    public String toString() {
        return new StringJoiner(", ", BintrayCredentials.class.getSimpleName() + "[", "]")
                .add("user='" + user + "'")
                .add("key='" + key + "'")
                .toString();
    }
}
