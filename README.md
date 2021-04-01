# openjdk-installer:
Repository for creating installable packages for AdoptOpenJDK releases.

The packages are created using:
1. The Wix Toolset http://wixtoolset.org (Windows only)
2. [Packages](http://s.sudre.free.fr/Software/Packages/about.html) (Mac OS)
3. To install `.deb` file via Command Line, follow these steps:
  * **Install a package**: `sudo dpkg -i DEB_PACKAGE`
  * **Remove a package**: `sudo dpkg -r PACKAGE_NAME`
  * **Reconfigure an existing package**: `sudo dpkg-reconfigure PACKAGE_NAME`
4. For installing and managing `rpms` follow the steps below:
  * Install `alien` first: `sudo apt-get install alien`
  * Convert the package.rpm into a package.deb: `sudo alien -d package-name.rpm`
  * Convert the `package.rpm` into a `package.deb`, and install the generated package: `alien -i package-name.rpm`
  * If you want to keep alien from changing the version number use the following command: `alien -k rpm-package-file.rpm`

The available packages can be seen from the AdoptOpenJDK download pages: https://adoptopenjdk.net/releases.html.

If a package is documented here but is not present on the AdoptOpenJDK download pages it may be because it is still being developed. Feel free to ask for the latest status in the installer Slack channel at [https://adoptopenjdk.slack.com].

See the [CONFIGURATION.md](./CONFIGURATION.md) file for the details of each package.
