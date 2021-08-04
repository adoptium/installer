package net.adoptium.installer;

public enum VirtualMachine {

    HOTSPOT("hotspot", "hotspot", "Hotspot"),

    OPENJ9("openj9", "openj9", "Eclipse OpenJ9"),

    OPENJ9_XL("openj9xl", "openj9", "Eclipse OpenJ9 (Extra Large Heap)");

    private final String packageQualifier;

    private final String configQualifier;

    private final String description;

    VirtualMachine(String packageQualifier, String configQualifier, String description) {
        this.packageQualifier = packageQualifier;
        this.configQualifier = configQualifier;
        this.description = description;
    }

    public String packageQualifier() {
        return this.packageQualifier;
    }

    public String configQualifier() {
        return this.configQualifier;
    }

    public String description() {
        return this.description;
    }
}
