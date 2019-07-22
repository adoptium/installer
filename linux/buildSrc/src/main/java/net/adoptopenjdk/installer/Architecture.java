package net.adoptopenjdk.installer;

/**
 * Defines the supported hardware architectures.
 *
 * The enum names match the architecture names as defined by the AdoptOpenJDK
 * build pipelines.
 */
public enum Architecture {
    X64("amd64", "x86_64", 64),
    S390X("s390x", "s390x", 64),
    PPC64LE("ppc64el", "ppc64le", 64),
    ARM("armhf", "armhfp", 32),
    AARCH64("arm64", "aarch64", 64);

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
