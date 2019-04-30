package net.adoptopenjdk.installer.bintray;

import java.util.Collection;
import java.util.Collections;
import java.util.SortedSet;
import java.util.StringJoiner;
import java.util.TreeSet;

public class UpdatePackage {

    private final String subject;

    private final String repository;

    private final String name;

    private final String description;

    private final SortedSet<String> licenses;

    private final String vcsUrl;

    private final String websiteUrl;

    private UpdatePackage(
            String subject,
            String repository,
            String name,
            String description,
            SortedSet<String> licenses,
            String vcsUrl,
            String websiteUrl
    ) {
        this.subject = subject;
        this.repository = repository;
        this.name = name;
        this.description = description;
        this.licenses = licenses;
        this.vcsUrl = vcsUrl;
        this.websiteUrl = websiteUrl;
    }

    public String getSubject() {
        return subject;
    }

    public String getRepository() {
        return repository;
    }

    public String getName() {
        return name;
    }

    public String getDescription() {
        return description;
    }

    public SortedSet<String> getLicenses() {
        return licenses;
    }

    public String getVcsUrl() {
        return vcsUrl;
    }

    public String getWebsiteUrl() {
        return websiteUrl;
    }

    @Override
    public String toString() {
        return new StringJoiner(", ", UpdatePackage.class.getSimpleName() + "[", "]")
                .add("subject='" + subject + "'")
                .add("repository='" + repository + "'")
                .add("name='" + name + "'")
                .add("description='" + description + "'")
                .add("licenses=" + licenses)
                .add("vcsUrl='" + vcsUrl + "'")
                .add("websiteUrl='" + websiteUrl + "'")
                .toString();
    }

    public static class Builder {

        private String subject;

        private String repository;

        private String name;

        private String description;

        private final SortedSet<String> licenses = new TreeSet<>();

        private String vcsUrl;

        private String websiteUrl;

        public Builder subject(String subject) {
            this.subject = subject;
            return this;
        }

        public Builder repository(String repository) {
            this.repository = repository;
            return this;
        }

        public Builder name(String name) {
            this.name = name;
            return this;
        }

        public Builder description(String description) {
            this.description = description;
            return this;
        }

        public Builder licenses(Collection<String> licenses) {
            this.licenses.clear();
            this.licenses.addAll(licenses);
            return this;
        }

        public Builder licenses(String... licenses) {
            Collections.addAll(this.licenses, licenses);
            return this;
        }

        public Builder vcsUrl(String vcsUrl) {
            this.vcsUrl = vcsUrl;
            return this;
        }

        public Builder websiteUrl(String websiteUrl) {
            this.websiteUrl = websiteUrl;
            return this;
        }

        public UpdatePackage build() {
            return new UpdatePackage(subject, repository, name, description, licenses, vcsUrl, websiteUrl);
        }
    }
}
