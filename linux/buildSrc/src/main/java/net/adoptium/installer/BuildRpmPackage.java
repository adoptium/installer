package net.adoptium.installer;

import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.Internal;

import java.io.File;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class BuildRpmPackage extends AbstractBuildLinuxPackage {

    // Dashes are reserved characters in RPMs
    private static final String ILLEGAL_RPM_VERSION_CHARS = "[\\-]";

    private boolean signPackage;

    public BuildRpmPackage() {
        setGroup("Build");
        setDescription("Builds a rpm package");
    }

    @Input
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
                getArchitecture().rpmQualifier()
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
        List<String> arguments = new ArrayList<>();

        arguments.add("--input-type=dir");
        arguments.add(String.format("--output-type=%s", getPackageType()));
        arguments.add(String.format("--package=%s", getOutputFile()));
        arguments.add(String.format("--name=%s", getPackageName()));
        arguments.add(String.format("--version=%s", getRpmVersion()));
        arguments.add(String.format("--iteration=%s", getIteration()));
        arguments.add(String.format("--architecture=%s", getArchitecture().rpmQualifier()));
        arguments.add(String.format("--category=%s", getCategory()));
        arguments.add(String.format("--prefix=%s", getPrefix()));
        arguments.add(String.format("--maintainer=%s", getMaintainer()));
        arguments.add(String.format("--license=%s", getLicense()));
        arguments.add(String.format("--url=%s", getHomepage()));
        arguments.add(String.format("--description=%s", getPackageDescription()));
        arguments.add(String.format("--vendor=%s", getVendor()));
        arguments.add(String.format("--chdir=%s", getTemporaryDir()));

        if (getAfterInstallScript() != null) {
            arguments.add(String.format("--after-install=%s",
                    new File(getProject().getBuildDir(), getAfterInstallScript().getName())));
        }
        if (getBeforeRemoveScript() != null) {
            arguments.add(String.format("--before-remove=%s",
                    new File(getProject().getBuildDir(), getBeforeRemoveScript().getName())));
        }
        for (String dependency : collectDependencies()) {
            arguments.add(String.format("--depends=%s", dependency));
        }
        for (String providesEntry : collectProvides()) {
            arguments.add(String.format("--provides=%s", providesEntry));
        }

        arguments.add("--rpm-os=linux");
        arguments.add(String.format("--directories=%s/%s", getPrefix(), getJdkDirectoryName()));
        return arguments;
    }

    @Override
    Map<String, Object> templateContext() {
        Map<String, Object> context = new LinkedHashMap<>();
        context.put("architecture", getArchitecture().rpmQualifier());
        context.put("rpmIsaBits", getArchitecture().rpmIsaBits());
        context.put("jdkDirectoryName", getJdkDirectoryName());
        context.put("packageName", getPackageName());
        context.put("packageVersion", getPackageVersion());
        context.put("rpmVersion", getRpmVersion());
        context.put("prefix", getPrefix());
        context.put("vm", getVm());
        context.put("variant", getVariant());
        return context;
    }

    @Override
    protected void beforePackageBuild() {
        /*
         * Due do a bug in Gradle (https://github.com/gradle/gradle/issues/3982), symlinks in the JDK directory were
         * converted into file copies, but with the wrong permissions. This was fixed in
         * https://github.com/adoptium/installer/pull/234, but introduced a new problem: RPM is unable to
         * convert directories into symlinks. To proper approach to fix this would be to use a pretrans scriptlet,
         * but fpm does not allow to write them in Lua which is mandatory
         * (https://docs.fedoraproject.org/en-US/packaging-guidelines/Directory_Replacement/,
         * https://github.com/jordansissel/fpm/issues/1666). Because there are already installations in the wild with
         * the symlink, going back to the directory is not an option because that would break them, too. Migrating to
         * a symlink in a post-install script isn't possible, either, because that symlink would be removed by the
         * uninstall of the old package during an update. The solution with the lowest impact is just to delete the
         * directory/symlink. The man pages are still there, but accessing them is less convenient.
         */
        File jaMan = Paths.get(getTemporaryDir().getAbsolutePath(), getJdkDirectoryName(), "man", "ja").toFile();
        if (jaMan.exists()) {
            if (!getProject().delete(jaMan.getAbsolutePath())) {
                throw new RuntimeException("Could not delete " + jaMan.getAbsolutePath());
            }
        }
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

    @Internal
    String getRpmVersion() {
        return getPackageVersion().replaceAll(ILLEGAL_RPM_VERSION_CHARS, "_");
    }
}
