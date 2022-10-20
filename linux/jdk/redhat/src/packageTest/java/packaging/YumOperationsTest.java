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

import static org.assertj.core.api.Assertions.assertThat;
import static packaging.TestContainersUtil.runShell;

/**
 * Checks whether the built package can be installed, uninstalled, and so on using yum.
 *
 * @author Andreas Ahlenstorf
 */
class YumOperationsTest {

	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(RedHatFlavoursWithYum.class)
	void packageSuccessfullyInstalled(String distribution, String codename) throws Exception {
		
		Path hostRpm = RpmFiles.hostRpmPath();

		assertThat(hostRpm).exists();

		File containerRpm = new File("", hostRpm.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostRpm), containerRpm.toString())
				.start();

			Container.ExecResult result;

			// below part: only test x86_64 rpm package in docker container
			if (System.getenv("testArch") == "x86_64" || System.getenv("testArch") == "all") {
				result = runShell(container, "yum install -y " + containerRpm);
				assertThat(result.getExitCode()).isEqualTo(0);

				result = runShell(container, "rpm -qi " + System.getenv("PACKAGE"));
				assertThat(result.getExitCode()).isEqualTo(0);
				if (System.getenv("JDKGPG") != null) {
					assertThat(result.getStdout())
						.contains("Name        : " + System.getenv("PACKAGE"))
						.contains("Group       : java")
						.contains("License     : GPLv2 with exceptions")
						.contains("Signature   : RSA/SHA256,")
						.contains("Relocations : /usr/lib/jvm/" + System.getenv("PACKAGE"))
						.contains("Packager    : Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>");
				} else {
					assertThat(result.getStdout())
						.contains("Name        : " + System.getenv("PACKAGE"))
						.contains("Group       : java")
						.contains("License     : GPLv2 with exceptions")
						.contains("Signature   : (none)")
						.contains("Relocations : /usr/lib/jvm/" + System.getenv("PACKAGE"))
						.contains("Packager    : Eclipse Adoptium Package Maintainers <temurin-dev@eclipse.org>");
				}
			}
		}
	}
}
