package net.adoptopenjdk.installer;

import com.samskivert.mustache.Mustache;
import org.gradle.api.DefaultTask;
import org.gradle.api.resources.ResourceException;
import org.gradle.api.tasks.Input;
import org.gradle.api.tasks.InputDirectory;
import org.gradle.api.tasks.InputFile;
import org.gradle.api.tasks.Optional;
import org.gradle.api.tasks.OutputFile;
import org.gradle.api.tasks.TaskAction;

import java.io.BufferedReader;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.io.Reader;
import java.io.Writer;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static java.nio.charset.StandardCharsets.UTF_8;

public abstract class AbstractBuildLinuxPackage extends DefaultTask {
    /**
     * Name of the resulting package
     */
    private String packageName;

    /**
     * Version of the resulting package
     */
    private String packageVersion;

    /**
     * Name of the platform which the package is for, e.g. "amd64".
     */
    private String architecture;

    private String vm;

    private int iteration;

    private String category;

    private String vendor;

    private String maintainer;

    private String license;

    private String homepage;

    private String packageDescription;

    /**
     * Optional list of packages this package requires to be present to function, e.g. "libc6".
     */
    private Set<String> dependencies;

    private File dependenciesFile;

    private Set<String> provides;

    private File providesFile;

    private String prefix;

    private File afterInstallScript;

    private File beforeRemoveScript;

    /**
     * Path to the directory that should be packaged
     */
    private File prebuiltJdkDirectory;

    private String variant;

    @TaskAction
    public void exec() {
        cleanTemporaryDirectory();

        getProject().copy(copySpec -> {
            copySpec.from(getPrebuiltJdkDirectory());
            copySpec.into(new File(getTemporaryDir(), getJdkDirectoryName()));
        });

        Map<String, Object> templateContext = templateContext();
        getLogger().debug("Package template context: {}", templateContext());
        processTemplate(
                getAfterInstallScript(),
                new File(getProject().getBuildDir(), getAfterInstallScript().getName()),
                templateContext
        );
        processTemplate(
                getBeforeRemoveScript(),
                new File(getProject().getBuildDir(), getBeforeRemoveScript().getName()),
                templateContext
        );

        beforePackageBuild();

        getProject().exec(execSpec -> {
            getLogger().debug("fpm arguments: {}", fpmArguments());

            execSpec.commandLine("fpm");
            execSpec.args(fpmArguments());
        });

        afterPackageBuild();
    }

    @Input
    public String getPackageName() {
        return packageName;
    }

    public void setPackageName(String packageName) {
        this.packageName = packageName;
    }

    @Input
    public String getPackageVersion() {
        return packageVersion;
    }

    public void setPackageVersion(String packageVersion) {
        this.packageVersion = packageVersion;
    }

    @Input
    public String getArchitecture() {
        return architecture;
    }

    public void setArchitecture(String architecture) {
        this.architecture = architecture;
    }

    public String getVm() {
        return vm;
    }

    public void setVm(String vm) {
        this.vm = vm;
    }

    @Input
    public int getIteration() {
        return iteration;
    }

    public void setIteration(int iteration) {
        this.iteration = iteration;
    }

    @Input
    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    @Input
    public String getVendor() {
        return vendor;
    }

    public void setVendor(String vendor) {
        this.vendor = vendor;
    }

    @Input
    public String getMaintainer() {
        return maintainer;
    }

    public void setMaintainer(String maintainer) {
        this.maintainer = maintainer;
    }

    @Input
    public String getLicense() {
        return license;
    }

    public void setLicense(String license) {
        this.license = license;
    }

    @Input
    public String getHomepage() {
        return homepage;
    }

    public void setHomepage(String homepage) {
        this.homepage = homepage;
    }

    @Input
    public String getPackageDescription() {
        return packageDescription;
    }

    public void setPackageDescription(String packageDescription) {
        this.packageDescription = packageDescription;
    }

    @Input
    @Optional
    public Set<String> getDependencies() {
        return dependencies;
    }

    public void setDependencies(Set<String> dependencies) {
        this.dependencies = dependencies;
    }

    @InputFile
    @Optional
    public File getDependenciesFile() {
        return dependenciesFile;
    }

    public void setDependenciesFile(File dependenciesFile) {
        this.dependenciesFile = dependenciesFile;
    }

    @Input
    @Optional
    public Set<String> getProvides() {
        return provides;
    }

    public void setProvides(Set<String> provides) {
        this.provides = provides;
    }

    @InputFile
    @Optional
    public File getProvidesFile() {
        return providesFile;
    }

    public void setProvidesFile(File providesFile) {
        this.providesFile = providesFile;
    }

    @Input
    public String getPrefix() {
        return prefix;
    }

    public void setPrefix(String prefix) {
        this.prefix = prefix;
    }

    @InputFile
    @Optional
    public File getAfterInstallScript() {
        return afterInstallScript;
    }

    public void setAfterInstallScript(File afterInstallScript) {
        this.afterInstallScript = afterInstallScript;
    }

    @InputFile
    @Optional
    public File getBeforeRemoveScript() {
        return beforeRemoveScript;
    }

    public void setBeforeRemoveScript(File beforeRemoveScript) {
        this.beforeRemoveScript = beforeRemoveScript;
    }

    @InputDirectory
    public File getPrebuiltJdkDirectory() {
        return prebuiltJdkDirectory;
    }

    public void setPrebuiltJdkDirectory(String prebuiltJdkDirectory) {
        setDistributionDirectory(new File(prebuiltJdkDirectory));
    }

    public void setDistributionDirectory(File distributionDirectory) {
        this.prebuiltJdkDirectory = distributionDirectory;
    }

    @OutputFile
    public abstract File getOutputFile();

    public abstract String getPackageType();

    public abstract String getJdkDirectoryName();

    @Optional
    public String getVariant() {
        return variant;
    }

    /**
     * Allows to define a package variant, for example to build slightly differing packages to
     * cover distribution differences. If the {@code variant} is set, the packages will be output
     * to a folder with the name {@code variant}.
     */
    public void setVariant(String variant) {
        this.variant = variant;
    }

    List<String> fpmArguments() {
        List<String> arguments = new ArrayList<>();

        arguments.add("--input-type=dir");
        arguments.add(String.format("--output-type=%s", getPackageType()));
        arguments.add(String.format("--package=%s", getOutputFile()));
        arguments.add(String.format("--architecture=%s", getArchitecture()));
        arguments.add(String.format("--name=%s", getPackageName()));
        arguments.add(String.format("--version=%s", getPackageVersion()));
        arguments.add(String.format("--iteration=%s", getIteration()));
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

    abstract Map<String, Object> templateContext();

    Set<String> collectDependencies() {
        Set<String> collectedDependencies = new LinkedHashSet<>();
        if (getDependencies() != null) {
            collectedDependencies.addAll(getDependencies());
        }
        if (dependenciesFile != null) {
            collectedDependencies.addAll(readSetFromFile(dependenciesFile));
        }
        return collectedDependencies;
    }

    Set<String> collectProvides() {
        Set<String> collectedProvides = new LinkedHashSet<>();
        if (getProvides() != null) {
            collectedProvides.addAll(getProvides());
        }
        if (providesFile != null) {
            collectedProvides.addAll(readSetFromFile(providesFile));
        }
        return collectedProvides;
    }

    /**
     * Template method that is called before the package is built with FPM.
     *
     * For example it allows to place files into the package directory that are only required by a specific package
     * type.
     */
    abstract void beforePackageBuild();

    /**
     * Template method that is called after the package has been built with FPM.
     */
    abstract void afterPackageBuild();

    private void cleanTemporaryDirectory() {
        Set<String> contentsToRetain = new LinkedHashSet<>();
        contentsToRetain.add(getJdkDirectoryName());
        contentsToRetain.addAll(getDistributionSpecificPackageContents());

        File[] toDelete = getTemporaryDir().listFiles((dir, name) ->
                !contentsToRetain.contains(name)
        );
        if (toDelete != null) {
            getProject().delete((Object) toDelete);
        }
    }

    /**
     * Returns the names of distribution specific package contents.
     */
    abstract Set<String> getDistributionSpecificPackageContents();

    File getOutputDirectory() {
        File outputDirectory = getProject().getBuildDir();
        if (getVariant() != null && !getVariant().trim().isEmpty()) {
            outputDirectory = new File(outputDirectory, getVariant());
        }
        return outputDirectory;
    }

    void processTemplate(File inFile, File outFile, Map<String, Object> context) {
        try (
                InputStream inStream = new FileInputStream(inFile);
                Reader reader = new BufferedReader(new InputStreamReader(inStream, UTF_8));
                OutputStream outStream = new FileOutputStream(outFile);
                Writer writer = new BufferedWriter(new OutputStreamWriter(outStream, UTF_8))
        ) {
            Mustache.compiler().escapeHTML(false).compile(reader).execute(context, writer);
        } catch (IOException e) {
            throw new ResourceException("Could not process template: " + inFile.toPath(), e);
        }
    }

    Set<String> readSetFromFile(File inFile) {
        try (
                InputStream inStream = new FileInputStream(inFile);
                BufferedReader reader = new BufferedReader(new InputStreamReader(inStream, UTF_8))
        ) {
            Set<String> readEntries = new LinkedHashSet<>();

            String line;
            while ((line = reader.readLine()) != null) {
                String entry = line.trim();

                if (line.isEmpty()) {
                    continue;
                }

                readEntries.add(entry);
            }

            return readEntries;
        } catch (IOException e) {
            throw new ResourceException("Could not read entries from " + inFile.toPath(), e);
        }
    }

    Map<String, String> readMapFromFile(File inFile) {
        try (
                InputStream inStream = new FileInputStream(inFile);
                BufferedReader reader = new BufferedReader(new InputStreamReader(inStream, UTF_8))
        ) {
            LinkedHashMap<String, String> readEntries = new LinkedHashMap<>();

            String line;
            while ((line = reader.readLine()) != null) {
                String entry = line.trim();

                if (line.isEmpty()) {
                    continue;
                }

                String[] results = entry.split("\\s");

                if (results.length != 2) {
                    throw new ResourceException("Illegal entry: '" + entry + "' in " + inFile.toPath());
                }

                readEntries.put(results[0], results[1]);
            }

            return readEntries;
        } catch (IOException e) {
            throw new ResourceException("Could not read entries from " + inFile.toPath(), e);
        }
    }
}
