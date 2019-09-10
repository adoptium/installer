package net.adoptopenjdk.installer;

import org.gradle.api.UncheckedIOException;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.InputFile;
import org.gradle.api.tasks.Optional;
import org.gradle.api.tasks.OutputFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.StringJoiner;
import java.util.stream.Collectors;

public class BuildDebianPackage extends AbstractBuildLinuxPackage {

    // Underscores are illegal in DEB version numbers
    private static final String ILLEGAL_DEB_VERSION_CHARS = "[_]";

    /**
     * Map of tools with their path relative to the root directory of the JDK (key, e.g.
     * "bin/javac") and their type (value, e.g. "jdkhl").
     */
    private Map<String, String> tools;

    private File toolsFile;

    private File jinfoFile;
    private int priority;

    public BuildDebianPackage() {
        setGroup("Build");
        setDescription("Builds a debian package");
    }

    @Input
    @Optional
    public Map<String, String> getTools() {
        return tools;
    }

    public void setTools(Map<String, String> tools) {
        this.tools = tools;
    }

    @InputFile
    @Optional
    public File getToolsFile() {
        return toolsFile;
    }

    public void setToolsFile(File toolsFile) {
        this.toolsFile = toolsFile;
    }

    @InputFile
    public File getJinfoFile() {
        return jinfoFile;
    }

    public void setJinfoFile(File jinfoFile) {
        this.jinfoFile = jinfoFile;
    }

    @Override
    @OutputFile
    public File getOutputFile() {
        // Result looks like openjdk-11-jdk_11.0.1+13-3ubuntu3.18.10.1_amd64.deb
        String outputFileName = String.format(
                "%s_%s-%s_%s.deb",
                getPackageName(),
                getPackageVersion(),
                getIteration(),
                getArchitecture().debQualifier()
        );
        return new File(getOutputDirectory(), outputFileName);
    }

    private String getJinfoName() {
        return String.format(".%s.jinfo", getJdkDirectoryName());
    }

    @Override
    public String getPackageType() {
        return "deb";
    }

    @Override
    public String getJdkDirectoryName() {
        return String.format("%s-%s", getPackageName(), getArchitecture().debQualifier());
    }

    @Override
    List<String> fpmArguments() {
        List<String> arguments = new ArrayList<>();

        arguments.add("--input-type=dir");
        arguments.add(String.format("--output-type=%s", getPackageType()));
        arguments.add(String.format("--package=%s", getOutputFile()));
        arguments.add(String.format("--name=%s", getPackageName()));
        arguments.add(String.format("--version=%s", getDebVersion()));
        arguments.add(String.format("--iteration=%s", getIteration()));
        arguments.add(String.format("--architecture=%s", getArchitecture().debQualifier()));
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

        return arguments;
    }

    @Override
    Map<String, Object> templateContext() {
        Set<JdkTool> jdkTools = collectTools();
        String toolsAsLine = jdkTools.stream()
                .map(JdkTool::getName)
                .collect(Collectors.joining(" "));

        Map<String, Object> context = new LinkedHashMap<>();
        context.put("architecture", getArchitecture().debQualifier());
        context.put("jdkDirectoryName", getJdkDirectoryName());
        context.put("packageName", getPackageName());
        context.put("packageVersion", getPackageVersion());
        context.put("debVersion", getDebVersion());
        context.put("prefix", getPrefix());
        context.put("priority", getPriority());
        context.put("tools", jdkTools);
        context.put("toolsAsLine", toolsAsLine);
        context.put("vm", getVm());
        context.put("variant", getVariant());
        return context;
    }

    Set<JdkTool> collectTools() {
        Set<JdkTool> collectedTools = new LinkedHashSet<>();
        if (getTools() != null) {
            for (Map.Entry<String, String> entry : getTools().entrySet()) {
                collectedTools.add(new JdkTool(entry.getKey(), entry.getValue()));
            }
        }
        if (toolsFile != null) {
            for (Map.Entry<String, String> entry : readMapFromFile(toolsFile).entrySet()) {
                collectedTools.add(new JdkTool(entry.getKey(), entry.getValue()));
            }
        }
        return collectedTools;
    }

    @Override
    void beforePackageBuild() {
        Map<String, Object> templateContext = templateContext();
        processTemplate(
                getJinfoFile(),
                new File(getTemporaryDir(), getJinfoName()),
                templateContext
        );

        // The upstream packages provided by Debian and Ubuntu place a symlink to src.zip in the root directory of the
        // Java distribution. Some of the AdoptOpenJDK releases already have the src.zip in the root directory, others
        // have it in lib/. If there's already a src.zip, do nothing, otherwise we create a symlink to lib/src.zip.
        Path link = Paths.get(getTemporaryDir().toString(), getJdkDirectoryName(), "src.zip");

        // The target path must be relative, otherwise it contains the full path to the build
        // directory which usually does not correspond to the installation directory on the target machine.
        Path target = Paths.get("lib", "src.zip");
        if (!link.toFile().exists()) {
            try {
                Files.createSymbolicLink(link, target);
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        }
    }

    @Override
    void afterPackageBuild() {
        // No post processing needed
    }

    @Override
    Set<String> getDistributionSpecificPackageContents() {
        return Collections.singleton(getJinfoName());
    }

    @Input
    public int getPriority() {
        return priority;
    }

    public void setPriority(int priority) {
        this.priority = priority;
    }

    String getDebVersion() {
        return getPackageVersion().replaceAll(ILLEGAL_DEB_VERSION_CHARS, "-");
    }

    static class JdkTool {

        private final String path;

        private final String type;

        JdkTool(String path, String type) {
            this.path = path;
            this.type = type;
        }

        public String getPath() {
            return path;
        }

        public String getType() {
            return type;
        }

        public String getName() {
            int separatorIdx = path.lastIndexOf('/');
            if (separatorIdx < 0) {
                return path;
            }

            return path.substring(separatorIdx + 1);
        }

        @Override
        public String toString() {
            return new StringJoiner(", ", JdkTool.class.getSimpleName() + "[", "]")
                    .add("path='" + path + "'")
                    .add("type='" + type + "'")
                    .toString();
        }
    }
}
