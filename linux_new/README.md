# Linux Packages of Eclipse Adoptium (`linux_new`)

We package Eclipse Temurin for Debian, Alpine, Red Hat, and SUSE (DEB, APK, and RPM) Linux distributions.

The pipeline is driven by a Jenkins [`Jenkinsfile`](Jenkinsfile) which orchestrates the following stages for each requested version and distribution combination:

1. **Validate artifacts** — confirm the upstream Temurin binary exists in Artifactory
2. **Generate spec file** — render Jinja2 templates via [`generate_spec.py`](generate_spec.py) to produce distribution-specific build specs
3. **Build packages** — run the packaging toolchain inside a Docker container
4. **Archive artifacts** — archive built packages in Jenkins
5. **Publish packages** — upload signed packages to the Adoptium package repository

The published packages are available at: https://packages.adoptium.net/ui/packages

---

## Template Structure

Templates are stored under `{jdk,jre}/<distro>/src/main/packaging/temurin/`.

### Shared (`common/`) templates

Version-specific template files have been consolidated into a single `common/` directory per distribution family. Jinja2 conditionals handle version-varying behaviour (tool lists, `Provides:` entries, package priority, etc.). Adding a new JDK version requires **no new template files**.

| Distribution | Shared template location |
|---|---|
| Alpine (APK) | `jdk/alpine/src/main/packaging/temurin/common/alpine.jdk.template.j2` |
| Debian (DEB) | `jdk/debian/src/main/packaging/temurin/common/debian/` |

The pipeline resolves templates using a **per-version-first, `common/` fallback** strategy: if a version-specific file exists it takes precedence, otherwise the shared template is used. This allows per-version overrides to be added without breaking the shared case.

> **Exception:** JDK 8 Alpine retains a dedicated per-version template (`temurin/8/`) because its version-string expansion format differs from JDK 11+.

### Shared Java test files (Alpine)

`HelloWorld.java`, `TestCryptoLevel.java`, and `TestECDSA.java` live once in `jdk/alpine/src/main/packaging/temurin/common/` and are referenced by all Alpine builds.

---

## Jenkins Pipeline Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `JAVA_TO_BUILD` | String | — | JDK version to build (e.g. `jdk21`) |
| `ARCHITECTURE` | Choice | — | Target architecture |
| `PACKAGE_TYPE` | Choice | — | `jdk` or `jre` |
| `DRY_RUN` | Boolean | `false` | Skip the entire pipeline (validation only) |
| `SKIP_UPLOAD` | Boolean | `false` | Build and archive packages but **do not publish** to Artifactory. Useful for validating template or packaging changes without touching the production repository. |

---

## Prerequisites (local development)

* Docker 20.10+ installed and running
* Python 3.x with `jinja2` and `pyyaml` installed (for `generate_spec.py`)
* Java 8+ (for the Gradle build steps if running the full Gradle-based check)

---

## Running `generate_spec.py` locally

`generate_spec.py` renders a Jinja2 template for a given version and distribution. It resolves templates using the same fallback logic as the pipeline (per-version first, then `common/`).

```shell
python3 linux_new/generate_spec.py \
    --version 21 \
    --ptype jdk \
    --distro alpine \
    --product temurin \
    --output /tmp/generated
```

---

## Supported Packages

### APK (Alpine)

- Supported JDK versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported JRE versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported platforms: `x86_64`

| Distro        | Test enabled platforms |
|---------------|:----------------------:|
| alpine/3.x.x  |         x86_64         |

### DEB (Debian / Ubuntu)

- Supported JDK versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported JRE versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported platforms: `amd64`, `arm64`, `armhf`, `ppc64le`, `s390x` _(s390x only for JDK > 8)_

| Distro                        | Test enabled platforms |
|-------------------------------|:----------------------:|
| debian/13 (trixie)            |         x86_64         |
| debian/12 (bookworm)          |         x86_64         |
| debian/11 (bullseye)          |         x86_64         |
| ubuntu/26.04 (resolute)       |         x86_64         |
| ubuntu/24.04 (noble)          |         x86_64         |
| ubuntu/22.04 (jammy)          |         x86_64         |
| ubuntu/20.04 (focal)          |         x86_64         |
| ubuntu/18.04 (bionic)         |         x86_64         |

- Debian releases: https://www.debian.org/releases/index.en.html
- Ubuntu releases: https://ubuntu.com/about/release-cycle

### RPM (Red Hat and SUSE)

- Supported JDK versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported JRE versions: 8, 11, 17, 21, 23, 24, 25, 26, 27, 28
- Supported platforms: `x86_64`, `aarch64`, `armv7hl`, `ppc64le`, `s390x` _(s390x only for JDK > 8)_
- SRPM also available.

| Distro          | Test enabled platforms | Note                                         |
|-----------------|:----------------------:|:---------------------------------------------|
| amazonlinux/2   |         x86_64         |                                              |
| centos/7        |         x86_64         |                                              |
| fedora/35–39    |         x86_64         |                                              |
| oraclelinux/7   |         x86_64         |                                              |
| oraclelinux/8   |         x86_64         |                                              |
| opensuse/15.3   |         x86_64         |                                              |
| opensuse/15.4   |         x86_64         |                                              |
| opensuse/15.5   |         x86_64         |                                              |
| rocky/8         |         x86_64         |                                              |
| rhel/7          |         x86_64         |                                              |
| rhel/8          |         x86_64         |                                              |
| rhel/9          |         x86_64         |                                              |
| sles/12         |          —             | Requires subscription to run zypper update   |
| sles/15         |         x86_64         |                                              |

---

## Error Handling

The pipeline raises a build failure if:

- The upstream Temurin artifact cannot be found or downloaded (download retries are attempted before failing)
- Package build produces no output artifacts
- Post-publish validation confirms that expected packages are not present in Artifactory after upload

Silent failures (green Jenkins build despite missing packages) have been addressed — the pipeline will now fail explicitly in these scenarios.

---

## Installing the Packages

See [Eclipse Temurin Linux (RPM/DEB) installer packages](https://adoptium.net/installation/linux/)
