# macOS installers

## Prerequisites

The installer is built with Apple's `pkgbuild` and `productbuild`, supplied with
macOS. The third-party Packages application is no longer required.

## Example Usage

Run from this directory, or invoke the script by its path from another directory.
Input and output paths, and an explicitly supplied `--logo`, are relative to the
current working directory.

```bash
./packagesbuild.sh --major_version 17 --full_version 17.0.3+7 --input_directory /path/to/jdk --output_directory OpenJDK17U-jdk_x64_mac_hotspot_17.0.3_7.pkg --jvm hotspot --architecture x86_64 --type jdk
```

The existing script name and arguments are retained for build-job compatibility,
except for local signing, which has been removed. Despite its historical name,
`--output_directory` names the output **file**.

The native build preserves:

- The package identifiers (`net.temurin.<major>.jdk` / `.jre`, or
  `net.temurin.<major>-openj9.jdk` / `.jre`) and `--identifier` override.
- The version supplied via `--full_version`, including build and LTS suffixes.
- Installation under `/Library/Java/JavaVirtualMachines`, with the same bundle
  names, root ownership, executable permissions and symbolic links. Existing
  shared-directory permissions are not overwritten.
- Non-relocatable, version-checked bundles and root-volume-only installation.
- The existing preinstall script.
- The welcome, license and conclusion pages, package title, and bottom-left logo
  in light and dark mode. OpenJ9 uses its existing separate license.
- The `--vendor`, `--package-name`, `--logo`, JVM, JDK/JRE and architecture options.
- Exclusion of build/SCM metadata from the payload.

[distribution.xml.template](./distribution.xml.template) describes the Installer
UI and installation domains; [components.plist.template](./components.plist.template)
controls bundle relocation and version checking. Builds use isolated temporary
directories and do not modify the source bundle or generated resources in the
checkout. Existing signatures on the JDK payload are retained.
Download quarantine attributes are not copied into the installable payload.
After `pkgbuild`, the component's `PackageInfo` is adjusted to retain the old
`overwrite-permissions="false"` policy, then repacked with `pkgutil`.

The archive-based entry point is still [create-installer-mac.sh](./create-installer-mac.sh).
Set `WORKSPACE`, `MAJOR_VERSION`, and `FULL_VERSION`; the JVM variant is inferred
from each archive filename. It reads matching archives under
`$WORKSPACE/workspace/target` and writes each `.pkg` beside its archive.
`SEARCH_PATTERN` can override `OpenJDK*-j*.tar.gz`. As before, each source archive
is removed only after its installer builds successfully.

The GitHub Actions workflow resolves the available LTS versions from
`/v3/info/available_releases`, then asks the Adoptium latest-assets API for each
supported macOS architecture and JDK/JRE combination. Unsupported combinations
(currently Java 8 on Apple silicon) are omitted. The generated matrix carries
the API's latest archive URL, filename and `openjdk_version` into independent
builds. Every downloaded source archive is verified against the SHA-256 checksum
returned by the API; no release version is pinned in the workflow.

## Signing and notarization

The build produces an **unsigned** installer. Signing and notarization remain
separate release steps through the Eclipse service, using
[eclipse-codesign.sh](../codesign/eclipse-codesign.sh) and
[eclipse-notarize.sh](../codesign/eclipse-notarize.sh). No keychain access, password
file, ad-hoc re-signing or local notarization is performed during packaging.
The former `--sign` option now reports an error instead of silently producing an
unsigned package. The legacy `CERTIFICATE` environment variable is ignored;
if set, it produces a warning. The existing Jenkins invocation and downstream
signing service require no changes.

Unsigned local packages are for testing, not distribution. To preview one, open
the `.pkg` in Installer.app. Nothing is installed until you choose **Install**
and authorize it.

This migration does not add advertising or change the standard Installer UI.

## Validation

On macOS, run:

```bash
bash test/functional/pkgbuild/runInstallerTests.sh
bash test/functional/pkgbuild/testUpgradeDowngrade.sh
PYTHONPATH=. python3 -m unittest discover -s test/functional/pkgbuild -p 'test_*.py'
```

Run these from the repository root. The first test builds and expands small
fixture packages. The upgrade test installs isolated fixtures into a temporary
directory in the current user's home, compares native and upstream-style
upgrade and downgrade behavior, and removes its unique per-user receipts and
files afterward. It does not modify installed JDKs or require administrator
privileges. The tests compare legacy and native behavior rather than assuming
every JDK version rejects downgrades.
