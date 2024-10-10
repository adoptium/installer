# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import os

import requests
import requests_cache
import yaml
from jinja2 import Environment, FileSystemLoader

requests_cache.install_cache("adoptium_cache", expire_after=3600)

# Setup the Jinja2 environment
env = Environment(loader=FileSystemLoader("templates"))

headers = {
    "User-Agent": "Adoptium Linux Specfile Updater",
}


def archHelper(arch):
    if arch == "x64":
        return "x86_64"
    else:
        return arch


# Load the YAML configuration
with open("config/temurin.yml", "r") as file:
    config = yaml.safe_load(file)

for image_type in ["jdk", "jre"]:
    # Iterate through supported_distributions
    for distro in config["supported_distributions"]["Distros"]:
        for version in config["supported_distributions"]["Versions"]:

            # Fetch latest release for version from Adoptium API
            url = f"https://api.adoptium.net/v3/assets/feature_releases/{version}/ga?page=0&image_type={image_type}&os=alpine-linux&page_size=1&vendor=eclipse"
            response = requests.get(url, headers=headers)
            response.raise_for_status()
            data = response.json()

            release = response.json()[0]

            # Extract the version number from the release name
            openjdk_version = release["release_name"]

            # If version doesn't equal 8, get the more accurate version number
            if version != 8:
                openjdk_version = release["version_data"]["openjdk_version"]
                # if openjdk_version contains -LTS remove it
                if "-LTS" in openjdk_version:
                    openjdk_version = openjdk_version.replace("-LTS", "")

            # Convert version from 11.0.24+8 to 11.0.24_p8
            openjdk_version = openjdk_version.replace("jdk", "")
            openjdk_version = openjdk_version.replace("+", "_p")
            openjdk_version = openjdk_version.replace("u", ".")
            openjdk_version = openjdk_version.replace("-b", ".")

            # Generate the data for each architecture
            arch_data = {}

            for binary in release["binaries"]:
                arch_data[archHelper(binary["architecture"])] = {
                    "download_url": binary["package"]["link"],
                    "checksum": binary["package"]["checksum"],
                    "filename": binary["package"]["name"],
                }

            # Set path to the specfiles
            path = f"{image_type}/{distro}/src/main/packaging/temurin/{version}"

            # Check that the path exists
            os.makedirs(path, exist_ok=True)

            # Load the template
            template = env.get_template(f"{distro}.spec.j2")

            # Render the template
            rendered = template.render(
                arch_data=arch_data,
                openjdk_version=openjdk_version,
                release_name=release["release_name"],
                version=version,
                image_type=image_type,
            )

            # Set filename based on switch distro e.g APKBUILD for alpine, spec for others
            match distro:
                case "alpine":
                    filename = "APKBUILD"
                case _:
                    print(f"Unsupported distro: {distro}")
                    exit(1)

            # Write the rendered template to the file
            with open(f"{path}/{filename}", "w") as file:
                file.write(rendered)
                print(f"Generated {path}/{filename}")
