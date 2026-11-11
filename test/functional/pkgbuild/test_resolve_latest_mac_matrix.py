#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

import unittest

from pkgbuild.resolve_latest_mac_matrix import resolve_latest_matrix


class LatestMacMatrixTests(unittest.TestCase):
    def test_builds_matrix_from_available_lts_api_assets(self):
        requests = []

        def fake_api(url):
            requests.append(url)
            if url.endswith("/info/available_releases"):
                return {"available_lts_releases": [8, 11]}

            major = int(url.split("/assets/latest/")[1].split("/")[0])
            architecture = url.split("architecture=")[1].split("&")[0]
            image_type = url.split("image_type=")[1].split("&")[0]
            if major == 8 and architecture == "aarch64":
                return []

            architecture_name = architecture
            package_name = (
                f"OpenJDK{major}U-{image_type}_{architecture_name}_mac_hotspot_"
                f"{'8u504b01' if major == 8 else '11.0.33_10'}.tar.gz"
            )
            return [
                {
                    "binary": {
                        "architecture": architecture,
                        "image_type": image_type,
                        "jvm_impl": "hotspot",
                        "package": {
                            "name": package_name,
                            "link": f"https://github.com/adoptium/temurin{major}-binaries/releases/download/tag/{package_name}",
                            "checksum": "a" * 64,
                        },
                    },
                    "release_name": f"release-{major}",
                    "version": {
                        "major": major,
                        "openjdk_version": (
                            "1.8.0_504-b01" if major == 8 else "11.0.33+10"
                        ),
                    },
                }
            ]

        matrix = resolve_latest_matrix(fake_api)

        self.assertEqual(len(requests), 9)
        self.assertEqual(len(matrix), 6)
        self.assertEqual(
            {(entry["major_version"], entry["architecture"], entry["image_type"]) for entry in matrix},
            {
                (8, "x64", "jdk"),
                (8, "x64", "jre"),
                (11, "x64", "jdk"),
                (11, "x64", "jre"),
                (11, "aarch64", "jdk"),
                (11, "aarch64", "jre"),
            },
        )
        java8 = matrix[0]
        self.assertEqual(java8["package_architecture"], "x86_64")
        self.assertEqual(java8["full_version"], "1.8.0_504-b01")
        self.assertEqual(java8["release_name"], "release-8")
        self.assertEqual(java8["archive_sha256"], "a" * 64)
        self.assertTrue(java8["archive_url"].endswith(java8["archive_name"]))
        self.assertEqual(
            {entry["full_version"] for entry in matrix if entry["major_version"] == 11},
            {"11.0.33+10"},
        )

    def test_requires_valid_openjdk_version(self):
        def fake_api(url):
            if url.endswith("/info/available_releases"):
                return {"available_lts_releases": [25]}
            package_name = "OpenJDK25U-jdk_x64_mac_hotspot_25.0.5_8.tar.gz"
            return [{
                "binary": {
                    "architecture": "x64",
                    "image_type": "jdk",
                    "jvm_impl": "hotspot",
                    "package": {
                        "name": package_name,
                        "link": f"https://example.org/{package_name}",
                        "checksum": "a" * 64,
                    },
                },
                "release_name": "jdk-25.0.5+8",
                "version": {"major": 25, "openjdk_version": invalid_version},
            }]

        for invalid_version in (None, "", "v25.0.5", "25.0.5\nbad", 25):
            with self.subTest(invalid_version=invalid_version):
                with self.assertRaisesRegex(ValueError, "Invalid OpenJDK version"):
                    resolve_latest_matrix(fake_api)

    def test_preserves_lts_build_and_suffix(self):
        def fake_api(url):
            if url.endswith("/info/available_releases"):
                return {"available_lts_releases": [25]}
            architecture = url.split("architecture=")[1].split("&")[0]
            image_type = url.split("image_type=")[1].split("&")[0]
            name = f"OpenJDK25U-{image_type}_{architecture}_mac_hotspot_25.0.5_8.tar.gz"
            return [{
                "binary": {
                    "architecture": architecture,
                    "image_type": image_type,
                    "jvm_impl": "hotspot",
                    "package": {
                        "name": name,
                        "link": f"https://example.org/{name}",
                        "checksum": "a" * 64,
                    },
                },
                "release_name": "jdk-25.0.5+8",
                "version": {"major": 25, "openjdk_version": "25.0.5+8-LTS"},
            }]

        matrix = resolve_latest_matrix(fake_api)
        self.assertEqual(len(matrix), 4)
        self.assertEqual({entry["full_version"] for entry in matrix}, {"25.0.5+8-LTS"})

    def test_rejects_malformed_api_asset(self):
        def fake_api(url):
            if url.endswith("/info/available_releases"):
                return {"available_lts_releases": [17]}
            return [{"release_name": "bad", "binary": {}, "version": {}}]

        with self.assertRaisesRegex(ValueError, "Invalid latest asset metadata"):
            resolve_latest_matrix(fake_api)

    def test_rejects_archive_names_with_path_components(self):
        def fake_api(url):
            if url.endswith("/info/available_releases"):
                return {"available_lts_releases": [25]}
            architecture = url.split("architecture=")[1].split("&")[0]
            image_type = url.split("image_type=")[1].split("&")[0]
            name = f"OpenJDK25U-{image_type}_{architecture}_mac_hotspot_../../other.tar.gz"
            return [{
                "binary": {
                    "architecture": architecture,
                    "image_type": image_type,
                    "jvm_impl": "hotspot",
                    "package": {
                        "name": name,
                        "link": f"https://example.org/{name}",
                        "checksum": "a" * 64,
                    },
                },
                "release_name": "jdk-25.0.5+8",
                "version": {"major": 25, "openjdk_version": "25.0.5+8-LTS"},
            }]

        with self.assertRaisesRegex(ValueError, "Invalid latest asset metadata"):
            resolve_latest_matrix(fake_api)

    def test_rejects_missing_lts_releases(self):
        with self.assertRaisesRegex(ValueError, "no available LTS releases"):
            resolve_latest_matrix(lambda _url: {"available_lts_releases": []})


if __name__ == "__main__":
    unittest.main()
