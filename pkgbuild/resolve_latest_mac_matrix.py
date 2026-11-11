#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

"""Resolve the latest macOS Temurin JDK/JRE archives for each available LTS."""

import json
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

API_BASE = "https://api.adoptium.net/v3"
ARCHITECTURES = {
    "x64": "x86_64",
    "aarch64": "arm64",
}
IMAGE_TYPES = ("jdk", "jre")


def request_json(url):
    request = Request(url, headers={"User-Agent": "Eclipse-Adoptium-installer-ci/1.0"})
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def resolve_latest_matrix(fetch_json=request_json):
    releases = fetch_json(f"{API_BASE}/info/available_releases")
    lts_releases = releases.get("available_lts_releases")
    if not isinstance(lts_releases, list) or not lts_releases:
        raise ValueError("Adoptium API returned no available LTS releases")

    matrix = []
    for major_version in sorted(set(lts_releases)):
        if not isinstance(major_version, int) or major_version < 8:
            raise ValueError(f"Invalid Java LTS release from Adoptium API: {major_version!r}")

        for architecture, package_architecture in ARCHITECTURES.items():
            for image_type in IMAGE_TYPES:
                url = (
                    f"{API_BASE}/assets/latest/{major_version}/hotspot"
                    f"?architecture={architecture}&image_type={image_type}"
                    "&os=mac&vendor=eclipse"
                )
                assets = fetch_json(url)
                if not isinstance(assets, list):
                    raise ValueError(f"Unexpected Adoptium asset response for Java {major_version}")
                if not assets:
                    continue
                if len(assets) != 1:
                    raise ValueError(
                        f"Expected one latest asset for Java {major_version} "
                        f"{architecture} {image_type}, got {len(assets)}"
                    )

                asset = assets[0]
                binary = asset.get("binary", {})
                package = binary.get("package", {})
                version = asset.get("version", {})
                name = package.get("name", "")
                link = package.get("link", "")
                checksum = package.get("checksum", "")
                expected_prefix = f"OpenJDK{major_version}U-{image_type}_{architecture}_mac_hotspot_"
                if (
                    binary.get("architecture") != architecture
                    or binary.get("image_type") != image_type
                    or binary.get("jvm_impl") != "hotspot"
                    or version.get("major") != major_version
                    or not isinstance(name, str)
                    or re.fullmatch(
                        rf"{re.escape(expected_prefix)}[A-Za-z0-9._+-]+\.tar\.gz",
                        name,
                    ) is None
                    or not asset.get("release_name")
                    or not isinstance(link, str)
                    or not link.startswith("https://")
                    or not link.endswith("/" + name)
                    or not isinstance(checksum, str)
                    or len(checksum) != 64
                    or any(character not in "0123456789abcdefABCDEF" for character in checksum)
                ):
                    raise ValueError(
                        f"Invalid latest asset metadata for Java {major_version} "
                        f"{architecture} {image_type}"
                    )

                full_version = version.get("openjdk_version")
                if not isinstance(full_version, str) or not re.fullmatch(
                    r"[0-9][A-Za-z0-9.+_-]*", full_version
                ):
                    raise ValueError(
                        f"Invalid OpenJDK version in Adoptium metadata for Java "
                        f"{major_version} {architecture} {image_type}"
                    )

                matrix.append(
                    {
                        "major_version": major_version,
                        "architecture": architecture,
                        "package_architecture": package_architecture,
                        "image_type": image_type,
                        "full_version": full_version,
                        "release_name": asset["release_name"],
                        "archive_name": name,
                        "archive_url": link,
                        "archive_sha256": checksum.lower(),
                    }
                )

    if not matrix:
        raise ValueError("Adoptium API returned no macOS LTS JDK/JRE archives")
    return matrix


def main():
    try:
        print(json.dumps(resolve_latest_matrix(), separators=(",", ":")))
    except (HTTPError, URLError, TimeoutError, ValueError, json.JSONDecodeError) as error:
        print(f"Could not resolve latest macOS Temurin releases: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
