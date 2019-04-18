package net.adoptopenjdk.installer;

import org.gradle.api.tasks.Optional;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class BuildRpmPackage extends AbstractBuildLinuxPackage {

    private boolean signPackage;

    public BuildRpmPackage() {
        setGroup("Build");
        setDescription("Builds a rpm package");
    }

    @Optional
    public boolean isSignPackage() {
        return signPackage;
    }

    public void setSignPackage(boolean signPackage) {
        this.signPackage = signPackage;
    }

    @Override
    public File getOutputFile() {
        // Result should look like java-11-openjdk-11.0.ea.28-2.fc29.x86_64.rpm
        String outputFileName = String.format(
                "%s-%s-%s.%s.rpm",
                getPackageName(),
                getPackageVersion(),
                getIteration(),
                getArchitecture()
        );
        return new File(getOutputDirectory(), outputFileName);
    }

    @Override
    public String getPackageType() {
        return "rpm";
    }

    @Override
    public String getJdkDirectoryName() {
        return getPackageName();
    }

    @Override
    List<String> fpmArguments() {
        List<String> args = super.fpmArguments();
        args.add("--rpm-os=linux");
        args.add(String.format("--directories=%s/%s", getPrefix(), getJdkDirectoryName()));
        return args;
    }

    @Override
    Map<String, Object> templateContext() {
        Map<String, Object> context = new LinkedHashMap<>();
        context.put("architecture", getArchitecture());
        context.put("jdkDirectoryName", getJdkDirectoryName());
        context.put("packageName", getPackageName());
        context.put("packageVersion", getPackageVersion());
        context.put("prefix", getPrefix());
        context.put("vm", getVm());
        context.put("variant", getVariant());
        return context;
    }

    @Override
    protected void beforePackageBuild() {
        // No pre processing needed.
    }

    @Override
    void afterPackageBuild() {
        if (!isSignPackage()) {
            return;
        }

        getProject().exec(execSpec -> {
            List<String> args = new ArrayList<>();
            args.add("--addsign");
            args.add(getOutputFile().toString());

            getLogger().debug("rpmsign arguments: {}", args);

            execSpec.commandLine("rpmsign");
            execSpec.args(args);
        });
    }

    @Override
    Set<String> getDistributionSpecificPackageContents() {
        return Collections.emptySet();
    }
}
