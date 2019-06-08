package net.adoptopenjdk.installer;

import org.gradle.api.DefaultTask;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.Internal;
import org.gradle.api.tasks.Optional;
import org.gradle.api.tasks.TaskAction;
import org.jfrog.artifactory.client.Artifactory;
import org.jfrog.artifactory.client.ArtifactoryClientBuilder;
import org.jfrog.artifactory.client.model.RepoPath;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.List;

public class RemoveObsoletePackages extends DefaultTask {

    private String apiEndpoint = "https://adoptopenjdk.jfrog.io/adoptopenjdk";

    private String user;

    private String password;

    private String repository;

    private int daysToKeep;

    private Clock clock = Clock.systemUTC();

    public RemoveObsoletePackages() {
        setGroup("upload");
        setDescription("Removes old packages");
    }

    @Input
    @Optional
    public String getApiEndpoint() {
        return apiEndpoint;
    }

    public void setApiEndpoint(String apiEndpoint) {
        this.apiEndpoint = apiEndpoint;
    }

    @Input
    @Optional
    public String getUser() {
        return user;
    }

    public void setUser(String user) {
        this.user = user;
    }

    @Input
    @Optional
    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    @Input
    public String getRepository() {
        return repository;
    }

    public void setRepository(String repository) {
        this.repository = repository;
    }

    @Input
    public int getDaysToKeep() {
        return daysToKeep;
    }

    public void setDaysToKeep(int daysToKeep) {
        this.daysToKeep = daysToKeep;
    }

    @Internal("for testing purposes")
    public Clock getClock() {
        return clock;
    }

    public void setClock(Clock clock) {
        this.clock = clock;
    }

    @TaskAction
    public void exec() {
        Artifactory artifactory = ArtifactoryClientBuilder.create()
                .setUrl(getApiEndpoint())
                .setUsername(getUser())
                .setPassword(getPassword())
                .build();

        List<RepoPath> paths = artifactory.searches()
                .repositories(this.repository)
                .artifactsCreatedInDateRange(0, maximumAgeMillis())
                .doSearch();

        for (RepoPath path : paths) {
            if (!path.getItemPath().endsWith(".deb") && !path.getItemPath().endsWith(".rpm")) {
                continue;
            }

            getLogger().lifecycle("Removing {} from {}.", path.getRepoKey(), path.getItemPath());
            artifactory.repository(path.getRepoKey()).delete(path.getItemPath());
        }

        getLogger().lifecycle("All obsolete packages removed from repository {}.", this.getRepository());
    }

    private long maximumAgeMillis() {
        return Instant.now(getClock()).minus(getDaysToKeep(), ChronoUnit.DAYS).toEpochMilli();
    }
}
