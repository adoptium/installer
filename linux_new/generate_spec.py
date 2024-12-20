import sys
import os
from jinja2 import Environment, FileSystemLoader

def print_parameters(template_path, package_version, hardware_architecture, package_url, package_checksum, package_name, output_file_name, current_date, package_release_version, upstream_version, changelog_version, upstreamarm32_version):
    """
    Print the received parameters in a formatted manner.
    """
    print("Parameters received:")
    print(f"  Template Path          : {template_path}")
    print(f"  Package Version        : {package_version}")
    print(f"  Hardware Architecture  : {hardware_architecture}")
    print(f"  Package URL            : {package_url}")
    print(f"  Package Checksum       : {package_checksum}")
    print(f"  Package Name           : {package_name}")
    print(f"  Output File Name       : {output_file_name}")
    print(f"  Current Date           : {current_date}")
    print(f"  Pack Rel Version       : {package_release_version}")
    print(f"  Upstream Version       : {upstream_version}")
    print(f"  Changelog Version      : {changelog_version}")
    print(f"  Upstream ARM32 Version : {upstreamarm32_version}")

def render_template(template_path, package_version, hardware_architecture, package_url, package_checksum, package_name, output_file_name, current_date, package_release_version, upstream_version, changelog_version, upstreamarm32_version):
    """
    Render a Jinja2 template file using provided parameters and save the result to an output file specified by the user.

    Args:
        template_path (str): Path to the J2 template file.
        package_version (str): The JDK version for the package being built.
        hardware_architecture (str): The hardware architecture for the package.
        package_url (str): The URL of the GitHub binary file for this release.
        package_checksum (str): The validated SHA256 checksum of the binary specified in the URL.
        package_name (str): The filename of the package binary.
        output_file_name (str): The name of the output file to save the rendered content.
        current_date (str): The date to be used for changelogs etc.
        package_release_version (str): The package release version.
        upstream_version (str): The upstream release version.
        changelog_version (str): The version to be used in the changelog version
        upstreamarm32_version (str): The upstream version to be used for ARM32 on JDK8
    """
    # Get the directory of the template file and set the output file path in the same directory
    template_dir = os.path.dirname(template_path)
    output_path = os.path.join(template_dir, output_file_name)

    # Load the template environment and template file
    env = Environment(loader=FileSystemLoader(template_dir))
    template = env.get_template(os.path.basename(template_path))

    # Render the template with provided parameters
    rendered_content = template.render(
        package_version=package_version,
        hardware_architecture=hardware_architecture,
        package_url=package_url,
        package_checksum=package_checksum,
        package_name=package_name,
        current_date=current_date,
        package_release_version=package_release_version,
        upstream_version=upstream_version,
        changelog_version=changelog_version,
        upstreamarm32_version=upstreamarm32_version
    )

    # Write the rendered content to the output file
    with open(output_path, "w") as output_file:
        output_file.write(rendered_content)

    print(f"Template rendered and saved to {output_path}")

def main():
    # Define the expected parameter count (9 parameters + script name)
    expected_params = 12

    # Check if the correct number of arguments was provided ( add 1 for script name/system param)
    if len(sys.argv) != expected_params + 1:
        print("Error: Eleven parameters are required.")
        print("\nUsage:")
        print("  python3 script.py <Template Path> <Package Version> <Hardware Architecture> <Package URL> <Package Checksum> <Package Name> <Output File Name>")
        print("\nParameters:")
        print("  Template Path        - Path to the J2 template file for building the installer package")
        print("  Package Version      - The JDK version for the package being built")
        print("  Hardware Architecture- The hardware architecture for the package (e.g., x86_64)")
        print("  Package URL          - The URL of the GitHub binary file for this release")
        print("  Package Checksum     - The validated SHA256 checksum of the binary specified in the URL")
        print("  Package Name         - The filename of the package binary")
        print("  Output File Name     - The desired name for the rendered output file")
        print("  Current Date         - The current date")
        print("  Package Rel Version  - The current package release version")
        print("  Upstream Version     - The Upstream Source Version")
        print("  Changelog Version    - The version to be used in the package changelog")
        print("  Upstream ARM2 Version- The ARM32 Upstream Version Number")
        sys.exit(1)

    # Assign parameters to descriptive variable names
    template_path = sys.argv[1]
    package_version = sys.argv[2]
    hardware_architecture = sys.argv[3]
    package_url = sys.argv[4]
    package_checksum = sys.argv[5]
    package_name = sys.argv[6]
    output_file_name = sys.argv[7]
    current_date = sys.argv[8]
    package_release_version = sys.argv[9]
    upstream_version = sys.argv[10]
    changelog_version = sys.argv[11]
    upstreamarm32_version = sys.argv[12]

    # Print the parameters for debugging
    print_parameters(template_path, package_version, hardware_architecture, package_url, package_checksum, package_name, output_file_name, current_date, package_release_version, upstream_version, changelog_version, upstreamarm32_version)

    # Render the template with the provided parameters
    render_template(template_path, package_version, hardware_architecture, package_url, package_checksum, package_name, output_file_name, current_date, package_release_version, upstream_version, changelog_version, upstreamarm32_version)

if __name__ == "__main__":
    main()
