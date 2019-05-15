package net.adoptopenjdk.installer;

import java.io.File;
import java.util.Collection;
import java.util.LinkedHashSet;
import java.util.Set;

class DebianPackageUpload extends PackageUpload {

    private final Set<String> distributions;

    private final Set<String> components;

    private final Set<String> architectures;

    private DebianPackageUpload(
            File file,
            String repository,
            String remotePath,
            Set<String> distributions,
            Set<String> components,
            Set<String> architectures
    ) {
        super(file, repository, remotePath);
        this.distributions = distributions;
        this.components = components;
        this.architectures = architectures;
    }

    public Set<String> getDistributions() {
        return distributions;
    }

    public Set<String> getComponents() {
        return components;
    }

    public Set<String> getArchitectures() {
        return architectures;
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
            return new DebianPackageUpload(file, repository, remotePath, distributions, components, architectures);
        }
    }
}
