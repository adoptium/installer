# openjdk-installer:
Repository for creating installable packages for AdoptOpenJDK releases.

The packages are created using:
1. The Wix Toolset http://wixtoolset.org (Windows only)
2. [Packages](http://s.sudre.free.fr/Software/Packages/about.html) (Mac OS)
3. For putting together `.deb` and `rpms` head to this link: [linux subdir readme](https://github.com/adoptium/installer/tree/master/linux#readme)

The available packages can be seen from the AdoptOpenJDK download pages: https://adoptopenjdk.net/releases.html.

If a package is documented here but is not present on the AdoptOpenJDK download pages it may be because it is still being developed. Feel free to ask for the latest status in the installer Slack channel at [https://adoptopenjdk.slack.com].

See the [CONFIGURATION.md](./CONFIGURATION.md) file for the details of each package.
