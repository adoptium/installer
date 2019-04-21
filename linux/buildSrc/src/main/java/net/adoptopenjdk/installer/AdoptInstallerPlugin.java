package net.adoptopenjdk.installer;

import org.gradle.api.Plugin;
import org.gradle.api.Project;
import org.jetbrains.annotations.NotNull;

public class AdoptInstallerPlugin implements Plugin<Project> {
    @Override
    public void apply(@NotNull Project target) {
        // No default tasks
    }
}
