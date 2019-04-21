package net.adoptopenjdk.installer.bintray;

import java.io.File;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;
import java.util.StringJoiner;

public class DebianPackageUpload extends PackageUpload {

    private final Set<String> distributions;
    private final Set<String> components;
    private final Set<String> architectures;

    private DebianPackageUpload(
            File file,
            String subject,
            String repository,
            String name,
            String version,
            String remotePath,
            boolean autoPublish,
            Set<String> distributions,
            Set<String> components,
            Set<String> architectures
    ) {
        super(file, subject, repository, name, version, remotePath, autoPublish);
        this.distributions = distributions;
        this.components = components;
        this.architectures = architectures;
    }

    public String distributionsAsHeader() {
        return toCommaSeparatedSting(distributions);
    }

    public String componentsAsHeader() {
        return toCommaSeparatedSting(components);
    }

    public String architecturesAsHeader() {
        return toCommaSeparatedSting(architectures);
    }

    public static class Builder extends AbstractPackageUploadBuilder<DebianPackageUpload.Builder> {
        Set<String> distributions = new LinkedHashSet<>();

        Set<String> components = new LinkedHashSet<>();

        Set<String> architectures = new LinkedHashSet<>();

        public Builder distributions(Collection<String> distributions) {
            this.distributions.clear();
            this.distributions.addAll(distributions);
            return this;
        }

        public Builder components(Collection<String> components) {
            this.components.clear();
            this.components.addAll(components);
            return this;
        }

        public Builder architectures(Collection<String> architectures) {
            this.architectures.clear();
            this.architectures.addAll(architectures);
            return this;
        }

        @Override
        public DebianPackageUpload build() {
            return new DebianPackageUpload(
                    file,
                    subject,
                    repository,
                    name,
                    version,
                    remotePath,
                    autoPublish,
                    distributions,
                    components,
                    architectures
            );
        }
    }

    private static String toCommaSeparatedSting(Collection<String> strings) {
        StringJoiner joiner = new StringJoiner(",");
        for (String str : strings) {
            joiner.add(str);
        }
        return joiner.toString();
    }
}
