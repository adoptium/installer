package net.adoptopenjdk.installer.bintray;

import java.util.StringJoiner;

public class PackageIndexEntryJson {
    private final String name;

    private final boolean linked;

    public PackageIndexEntryJson(String name, boolean linked) {
        this.name = name;
        this.linked = linked;
    }

    public String getName() {
        return name;
    }

    public boolean isLinked() {
        return linked;
    }

    @Override
    public String toString() {
        return new StringJoiner(", ", PackageIndexEntryJson.class.getSimpleName() + "[", "]")
                .add("name='" + name + "'")
                .add("linked=" + linked)
                .toString();
    }
}
