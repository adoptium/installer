/*
 * Copyright 2021 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package packaging;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ArgumentsSource;
import org.testcontainers.containers.Container;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.MountableFile;

import java.io.File;
import java.nio.file.Path;
import java.nio.file.Paths;

import static org.assertj.core.api.Assertions.assertThat;
import static packaging.TestContainersUtil.runShell;

/**
 * Checks whether the built package can be installed, uninstalled, and so on using apt.
 *
 * @author Andreas Ahlenstorf
 */
class AptOperationsTest {

	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(DebianFlavours.class)
	void packageSuccessfullyInstalled(String distribution, String codename) throws Exception {
		Path certificatesHostDeb = Paths.get(getClass().getResource("/dependencies/deb/adoptium-ca-certificates_1.0.0-1_all.deb").toURI());
		Path hostDeb = DebFiles.hostDebPath();

		assertThat(hostDeb).exists();
		assertThat(certificatesHostDeb).exists();

		File containerDeb = new File("", hostDeb.toFile().getName());
		File certificatesDeb = new File("", certificatesHostDeb.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostDeb), containerDeb.toString())
				.withCopyFileToContainer(MountableFile.forHostPath(certificatesHostDeb), certificatesDeb.toString())
				.start();

			Container.ExecResult result;

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get update");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y apt-utils");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + certificatesDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + containerDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "apt-cache show " + System.getenv("PACKAGE"));
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.contains("Package: " + System.getenv("PACKAGE"))
				.contains("Priority: optional")
				.contains("Section: java")
				.contains("Status: install ok installed");
		}
	}
}
