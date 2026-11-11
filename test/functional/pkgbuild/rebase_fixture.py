#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0

"""Move a test package into a disposable current-user installation domain."""

import argparse
import plistlib
import shutil
import subprocess
from pathlib import Path, PurePosixPath
from xml.etree import ElementTree


def rebase_fixture(package_dir, relative_path, legacy):
    destination_path = PurePosixPath(relative_path)
    if (
        destination_path.is_absolute()
        or len(destination_path.parts) != 3
        or not destination_path.parts[0].startswith(".adoptium-installer-test.")
        or destination_path.parts[1] != "installed"
        or destination_path.parts[2] in {".", ".."}
        or not destination_path.parts[2].endswith((".jdk", ".jre"))
    ):
        raise ValueError(f"Unsafe test installation path: {relative_path}")

    component = package_dir / "payload.pkg"
    payload = component / "Payload"
    package_info_file = component / "PackageInfo"
    distribution_file = package_dir / "Distribution"
    info_tree = ElementTree.parse(package_info_file)
    info = info_tree.getroot()
    distribution_tree = ElementTree.parse(distribution_file)
    distribution = distribution_tree.getroot()

    bundle = info.find("./bundle")
    if bundle is None or "path" not in bundle.attrib:
        raise ValueError("Expected one pkgbuild bundle in the fixture")
    source_path = PurePosixPath(bundle.attrib["path"])
    if (
        len(source_path.parts) != 4
        or source_path.parts[:3] != ("Library", "Java", "JavaVirtualMachines")
        or not source_path.name.endswith((".jdk", ".jre"))
    ):
        raise ValueError(f"Unexpected source bundle path: {source_path}")

    source_bundle = payload.joinpath(*source_path.parts)
    with (source_bundle / "Contents" / "Info.plist").open("rb") as file:
        bundle_info = plistlib.load(file)
    bundle_id = bundle_info["CFBundleIdentifier"]
    package_id = info.attrib["identifier"]
    if bundle_id not in {package_id, f"{package_id}.bundle"}:
        raise ValueError("Unexpected fixture bundle identifier")

    destination_bundle = payload.joinpath(*destination_path.parts)
    destination_bundle.parent.mkdir(parents=True)
    shutil.move(source_bundle, destination_bundle)
    source_bundle.parent.rmdir()
    source_bundle.parent.parent.rmdir()
    source_bundle.parent.parent.parent.rmdir()

    scripts = info.find("./scripts")
    if scripts is None or len(scripts) != 1 or scripts[0].tag != "preinstall":
        raise ValueError("Expected only the production preinstall script")
    info.remove(scripts)
    (component / "Scripts" / "preinstall").unlink()
    (component / "Scripts").rmdir()

    if legacy:
        legacy_info = ElementTree.Element(
            "pkg-info",
            {
                "format-version": "2",
                "identifier": info.attrib["identifier"],
                "version": info.attrib["version"],
                "relocatable": "false",
                "overwrite-permissions": "false",
                "followSymLinks": "false",
                "install-location": "/",
                "auth": "none",
            },
        )
        payload_info = info.find("./payload")
        if payload_info is None:
            raise ValueError("Fixture package has no payload metadata")
        legacy_info.append(payload_info)
        bundle_version = ElementTree.SubElement(legacy_info, "bundle-version")
        ElementTree.SubElement(
            bundle_version,
            "bundle",
            {
                "path": f"./{destination_path}",
                "CFBundleShortVersionString": bundle_info["CFBundleShortVersionString"],
                "CFBundleVersion": bundle_info.get("CFBundleVersion", ""),
                "id": bundle_id,
                "CFBundleIdentifier": bundle_id,
            },
        )
        info_tree._setroot(legacy_info)
    else:
        info.set("auth", "none")
        for item in info.iter("bundle"):
            if "path" in item.attrib:
                if PurePosixPath(item.attrib["path"]) != source_path:
                    raise ValueError("Unexpected bundle path in package metadata")
                item.set("path", f"./{destination_path}")

    options = distribution.find("./options")
    if options is None or options.get("rootVolumeOnly") != "true":
        raise ValueError("Fixture distribution does not target only the root volume")
    if distribution.find("./domains") is not None:
        raise ValueError("Fixture distribution unexpectedly declares installation domains")
    del options.attrib["rootVolumeOnly"]
    domains = ElementTree.Element(
        "domains",
        {
            "enable_anywhere": "false",
            "enable_currentUserHome": "true",
            "enable_localSystem": "false",
        },
    )
    distribution.insert(list(distribution).index(options) + 1, domains)
    for package_ref in list(distribution.findall("./pkg-ref")):
        if legacy and package_ref.find("./bundle-version") is not None:
            distribution.remove(package_ref)
            continue
        if "auth" in package_ref.attrib:
            package_ref.set("auth", "None")
    for item in distribution.iter("bundle"):
        if "path" in item.attrib:
            if PurePosixPath(item.attrib["path"]) != source_path:
                raise ValueError("Unexpected bundle path in distribution metadata")
            item.set("path", str(destination_path))

    info_tree.write(package_info_file, encoding="utf-8", xml_declaration=True)
    distribution_tree.write(distribution_file, encoding="utf-8", xml_declaration=True)
    rebuilt_bom = component / "Bom.rebuilt"
    subprocess.run(["/usr/bin/mkbom", str(payload), str(rebuilt_bom)], check=True)
    rebuilt_bom.replace(component / "Bom")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("package_dir", type=Path)
    parser.add_argument("relative_path")
    parser.add_argument("--legacy", action="store_true")
    args = parser.parse_args()
    rebase_fixture(args.package_dir, args.relative_path, args.legacy)


if __name__ == "__main__":
    main()
