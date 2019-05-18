package net.adoptopenjdk.installer;

public enum Architecture {
    AMD64("amd64", "x86_64", 64),
    S390X("s390x", "s390x", 64),
    PPC64EL("ppc64el", "ppc64le", 64),
    ARM64("arm64", "aarch64", 64);

    private final String debQualifier;
    private final String rpmQualifier;
    private final int isaBits;

    Architecture(String debQualifier, String rpmQualifier, int isaBits) {
        this.debQualifier = debQualifier;
        this.rpmQualifier = rpmQualifier;
        this.isaBits = isaBits;
    }

    String debQualifier() {
        return this.debQualifier;
    }

    String rpmQualifier() {
        return this.rpmQualifier;
    }

    int isaBits() {
        return this.isaBits;
    }

    String rpmIsaBits() {
        return String.format("%sbit", this.isaBits);
    }
}
