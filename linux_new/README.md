# Linux Packages of Eclipse Adoptium (`linux_new`)

We package Eclipse Temurin for Debian/Ubuntu, Alpine, Red Hat, and SUSE (DEB, APK, and RPM) Linux distributions.

The pipeline is driven by a Jenkins [`Jenkinsfile`](Jenkinsfile) which orchestrates the following stages for each requested version and distribution combination:

1. **Print Parameters** — log all build flags, target tags, and parameters
2. **Process Parameters** — parse release version tags, derive target architectures, and set dynamic build agent node labels
3. **Validate Artifacts** — download upstream Temurin binary and SHA-256 checksum files from GitHub releases and verify checksum integrity
4. **Generate Spec File** — render Jinja2 templates via [`generate_spec.py`](generate_spec.py) to produce distribution-specific build specifications (`.spec`, `APKBUILD`, `control`, `rules`, `changelog`)
5. **Build & Archive Package** — run the packaging toolchain inside Docker containers across dedicated build nodes, and archive built packages
6. **Grype Vulnerability Scan** — execute automated, containerized **Grype vulnerability scanning** across all built packages on the target controller node (`NODE_LABEL`), archiving security reports (JSON, SARIF, Markdown, Plain Text)
7. **Publish Packages** — upload signed packages to Artifactory via JFrog CLI (`jf`)
8. **Verify Publication** — perform automated HTTP `HEAD` verification checks against Artifactory endpoints to confirm every published package is accessible
9. **Downstream Trigger** — trigger `publish_linux_pkg_src` for packaging source repository synchronization

The published packages are available at: https://packages.adoptium.net/ui/packages

---

## Template Structure

Templates are stored under `{jdk,jre}/<distro>/src/main/packaging/temurin/`.

### Shared (`common/`) Templates

Version-specific template files have been consolidated into a single `common/` directory per distribution family. Jinja2 conditionals handle version-varying behaviour (tool lists, `Provides:` entries, package priority, etc.). Adding a new JDK version requires **no new template files**.

| Distribution | Shared template location |
|---|---|
| Alpine (APK) | `jdk/alpine/src/main/packaging/temurin/common/alpine.jdk.template.j2` |
| Debian / Ubuntu (DEB) | `jdk/debian/src/main/packaging/temurin/common/debian/` |
| RHEL / Fedora / CentOS (RPM) | `jdk/rhel/src/main/packaging/temurin/common/temurin-jdk.template.j2` |
| SUSE / SLES (RPM) | `jdk/suse/src/main/packaging/temurin/common/temurin-jdk.template.j2` |

The pipeline resolves templates using a **per-version-first, `common/` fallback** strategy: if a version-specific file exists it takes precedence, otherwise the shared template is used. This allows per-version overrides to be added without breaking the shared case.

> **Exception:** JDK 8 retains dedicated per-version templates (`temurin/8/`) where version-string expansion formats differ from JDK 11+.

### Shared Java Test Files (Alpine)

`HelloWorld.java`, `TestCryptoLevel.java`, and `TestECDSA.java` live once in `jdk/alpine/src/main/packaging/temurin/common/` and are referenced by all Alpine builds.

---

## Grype Vulnerability Scanning

Automated content-based vulnerability scanning is integrated via [Anchore Grype](https://github.com/anchore/grype) located in [`grype/`](grype/).

### How Scanning Works

* **Scan Scope**: The installed content of each generated package (`release` metadata file, bundled JARs such as `jrt-fs.jar`, and ELF binaries). Distro runtime dependencies (e.g. `glibc`, `musl`) are excluded from scope.
* **Cataloguers Used**:
  * `java-jvm-cataloger`: Extracts OpenJDK version metadata from the bundled `release` file, generating an OpenJDK CPE (`cpe:2.3:a:oracle:openjdk:<version>`) matched against NVD and Oracle CPU advisories.
  * `java-archive-cataloger`: Fingerprints bundled JARs against GitHub Advisory Database.
  * `binary-classifier-cataloger`: Analyzes native ELF binaries.
* **Informational Mode**: The scan runs post-packaging in non-blocking mode. Findings at or above `--fail-on` (default: `high`) mark the Jenkins stage as `UNSTABLE` while preserving package publishing.

### Scanner Assets (`linux_new/grype/`)

* [`grype/Dockerfile`](grype/Dockerfile): Self-contained UBI 9 minimal scanner container installing Grype, archive extraction tools (`binutils`, `cpio`, `rpm`, `tar`, `xz`), and Python 3.
* [`grype/run-all-scans.sh`](grype/run-all-scans.sh): Unified runner that discovers all package types (`.apk`, `.deb`, `.rpm`) across build directories and generates aggregated reports.
* [`grype/grype-linux-scan.sh`](grype/grype-linux-scan.sh): Orchestrates DEB and RPM scans, automatically detecting package format and distro context.
* [`grype/grype-apk-scan.sh`](grype/grype-apk-scan.sh): Orchestrates Alpine APK scans.
* [`grype/grype-summary-report.py`](grype/grype-summary-report.py): Parses Grype JSON outputs to produce consolidated Markdown (`global-summary.md`) and Plain Text (`global-summary.txt`) reports.
* **Configuration Files**:
  * [`.grype.yaml`](grype/.grype.yaml): Alpine APK scanning configuration.
  * [`.grype-ubuntu.yaml`](grype/.grype-ubuntu.yaml): Ubuntu/Debian DEB scanning configuration.
  * [`.grype-rhel.yaml`](grype/.grype-rhel.yaml): RHEL/CentOS/Fedora RPM scanning configuration.
  * [`.grype-sles.yaml`](grype/.grype-sles.yaml): SUSE/SLES RPM scanning configuration.

### Running Scans Locally

```shell
# Scan RPM packages (RHEL / SUSE)
./linux_new/grype/grype-linux-scan.sh \
    --output-dir /tmp/grype-results \
    build/ospackage/*.rpm

# Scan Debian / Ubuntu DEB packages
./linux_new/grype/grype-linux-scan.sh \
    --distro ubuntu:24.04 \
    --output-dir /tmp/grype-results \
    build/ospackage/*.deb

# Scan Alpine APK packages
./linux_new/grype/grype-apk-scan.sh \
    --distro alpine:3.24 \
    --output-dir /tmp/grype-results \
    build/ospackage/*.apk

# Generate consolidated summary report
python3 ./linux_new/grype/grype-summary-report.py \
    /tmp/grype-results \
    --format markdown \
    --output /tmp/grype-results/summary.md
```

### Suppressing Accepted CVEs

When a reported finding is evaluated and confirmed as non-applicable or mitigated, add an entry to the `ignore:` list in the corresponding `.grype-*.yaml` configuration file:

```yaml
ignore:
  - vulnerability: CVE-YYYY-NNNNN
    package:
      name: openjdk
      type: rpm
    reason: 'Documented technical rationale and review date'
```

---

## Jenkins Pipeline Parameters

The pipeline is parameterized with the following settings in [`Jenkinsfile`](Jenkinsfile):

| Parameter | Type | Default | Description |
|---|---|---|---|
| `TAG` | String | `jdk-23+37` | Release tag to build (e.g. `jdk-23+37`, `jdk8u432-b06`) |
| `VERSION` | String | `jdk23` | Release version identifier (e.g. `jdk23`, `jdk8`) |
| `ARTIFACTS_TO_COPY` | String | (Path pattern) | Target artifact pattern used to determine target OS and architecture |
| `RELEASE` | Boolean | `false` | Marks official release build |
| `DRY_RUN` | Boolean | `false` | Run parameter validation without building or publishing packages |
| `SKIP_UPLOAD` | Boolean | `false` | Build, scan, and archive packages but skip publishing to Artifactory |
| `ENABLEGPGSIGNING` | Boolean | `true` | Enable GPG/RSA package signing |
| `ENABLEDEBUG` | Boolean | `false` | Enable `--stacktrace` debugging flag for Gradle builds |
| `ENABLE_GRYPE_SCAN` | Boolean | `true` | Run automated Grype vulnerability scanning on generated packages |
| `REPACKAGE` | Boolean | `false` | Rebuild an existing package version |
| `PACKAGE_INCREMENT` | String | `1` | Increment counter used for repackaged releases |
| `TEMURIN_VERSION_INCREMENT` | String | `0` | Temurin patch version increment |
| `SKIP_DEBIAN` | Boolean | `false` | Skip Debian/Ubuntu package build and upload |
| `SKIP_ALPINE` | Boolean | `false` | Skip Alpine APK package build and upload |
| `SKIP_RHEL` | Boolean | `false` | Skip RHEL RPM package build and upload |
| `SKIP_SUSE` | Boolean | `false` | Skip SUSE RPM package build and upload |
| `SKIP_SRC` | Boolean | `false` | Skip uploading source packages to GitHub |

---

## Prerequisites (Local Development)

* Docker 20.10+ installed and running
* Python 3.8+ with `jinja2` and `pyyaml` installed
* Anchore Grype CLI (`grype`) for local vulnerability scanning
* Java 17+ (for Gradle build orchestration)

---

## Running `generate_spec.py` Locally

`generate_spec.py` renders Jinja2 templates into package build specifications. It resolves templates using the same fallback logic as the pipeline (per-version first, then `common/`).

```shell
python3 linux_new/generate_spec.py \
    linux_new/jdk/alpine/src/main/packaging/temurin/common/alpine.jdk.template.j2 \
    "25.0.4.1_p1" \
    "x86_64" \
    "https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.4.1%2B1/..." \
    "checksum_sha256" \
    "OpenJDK25U-jdk_x64_alpine-linux_hotspot_25.0.4.1_1.tar.gz" \
    "APKBUILD" \
    "Wed, 01 Oct 2026 15:00:00 +0000" \
    "0" "" "25.0.4.1_p1" "" "25"
```

---

## Supported Packages & Platforms

### APK (Alpine)

- Supported JDK versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported JRE versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported architectures: `x86_64`, `aarch64`

### DEB (Debian / Ubuntu)

- Supported JDK versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported JRE versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported architectures: `amd64`, `arm64`, `armhf`, `ppc64el`, `s390x`, `riscv64`
- Target distributions:
  - Debian: `trixie` (13), `bookworm` (12), `bullseye` (11), `buster` (10)
  - Ubuntu: `resolute` (26.04), `noble` (24.04), `jammy` (22.04), `focal` (20.04), `bionic` (18.04)

### RPM (Red Hat, CentOS, Fedora, openSUSE, SLES)

- Supported JDK versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported JRE versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported architectures: `x86_64`, `aarch64`, `armv7hl`, `ppc64le`, `s390x`, `riscv64`
- Target distributions:
  - RHEL / CentOS / Rocky / Oracle: CentOS 7, 9, 10; RHEL 7, 8, 9, 10; Rocky 8; Oracle Linux 7, 8, 9, 10; Amazon Linux 2
  - Fedora: 35 through 45, `rawhide`
  - SUSE: openSUSE 15.3, 15.4, 15.5; SLES 12, 15

---

## Error Handling & Verification

The pipeline enforces strict failure checks:

* **Artifact Validation**: Fails if upstream binaries cannot be fetched or if SHA-256 checksums do not match.
* **Build Validation**: Fails if package builds produce no output or files under minimum size thresholds (10 MB).
* **Publication Verification**: Performs automated HTTP `HEAD` checks for every published package in Artifactory; fails if any endpoint returns non-`200`.
* **Grype Vulnerability Scans**: Runs in informational mode; unsuppressed high/critical findings mark the stage as `UNSTABLE` while preserving package delivery.

---

## Installing the Packages

For end-user installation instructions, see [Eclipse Temurin Linux (RPM/DEB/APK) Installation Guide](https://adoptium.net/installation/linux/).
