# openjdk-installer:
Repository for creating installable packages for AdoptOpenJDK releases.

The packages are created using:
1. The Wix Toolset [http://wixtoolset.org/] (Windows only)
1. BitRock InstallBuilder [https://installbuilder.bitrock.com] (all other platforms)
 - The AdoptOpenJDK project has been granted a license to use InstallBuilder to create installers for AdoptOpenJDK releases under their initiative to support open source projects: [https://installbuilder.bitrock.com/open-source-licenses.html].

The available packages can be see from the AdoptOpenJDK download pages: [https://adoptopenjdk.net/releases.html]

If a package is documented here but is not present on the AdoptOpenJDK download pages it may be because it is still being developed. Feel free to ask for the latest status in the installer Slack channel at [https://adoptopenjdk.slack.com].

See the [CONFIGURATION.md](./CONFIGURATION.md) file for the details of each package.
