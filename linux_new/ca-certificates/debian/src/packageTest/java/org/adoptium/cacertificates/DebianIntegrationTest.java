/*
 * Copyright 2020 the original author or authors.
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

package org.adoptium.cacertificates;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ArgumentsSource;
import org.testcontainers.containers.Container;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.utility.MountableFile;

import java.io.File;
import java.nio.file.Path;

import static org.adoptium.cacertificates.TestContainersUtil.runShell;
import static org.assertj.core.api.Assertions.assertThat;

/**
 * @author Andreas Ahlenstorf
 */
class DebianIntegrationTest {
	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(DebianFlavours.class)
	void keystoreIsUsable(String distribution, String codename) {
		Path hostDeb = DebFiles.hostDebPath();
		assertThat(hostDeb).exists();
		File containerDeb = new File("", hostDeb.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostDeb), containerDeb.toString())
				.start();

			Container.ExecResult result;

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get update");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + containerDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre");
			assertThat(result.getExitCode()).isEqualTo(0);

			// Certificate fingerprint it SwissSign Gold G2 (https://www.swisssign.com/support/ca-prod.html)
			result = runShell(
				container, "keytool -list -keystore /etc/ssl/certs/adoptium/cacerts -storepass changeit"
			);
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.containsIgnoringCase("Keystore type: jks")
				.containsIgnoringCase("Keystore provider: SUN")
				.contains("swisssigngoldca-g2");
		}
	}

	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(DebianFlavours.class)
	void keystoreCanBeUpdated(String distribution, String codename) {
		Path hostDeb = DebFiles.hostDebPath();
		assertThat(hostDeb).exists();
		File containerDeb = new File("", hostDeb.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostDeb), containerDeb.toString())
				.start();

			Container.ExecResult result;

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get update");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + containerDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(
				container, "keytool -list -keystore /etc/ssl/certs/adoptium/cacerts -storepass changeit"
			);
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.containsIgnoringCase("Keystore type: jks")
				.containsIgnoringCase("Keystore provider: SUN")
				.contains("swisssigngoldca-g2");

			result = runShell(container, "update-ca-certificates");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(
				container, "keytool -list -keystore /etc/ssl/certs/adoptium/cacerts -storepass changeit"
			);
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.containsIgnoringCase("Keystore type: jks")
				.containsIgnoringCase("Keystore provider: SUN")
				.contains("swisssigngoldca-g2");
		}
	}

	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(DebianFlavours.class)
	void deletedKeystoreIsRecreatedOnCaUpdate(String distribution, String codename) {
		Path hostDeb = DebFiles.hostDebPath();
		assertThat(hostDeb).exists();
		File containerDeb = new File("", hostDeb.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostDeb), containerDeb.toString())
				.start();

			Container.ExecResult result;

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get update");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + containerDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "test -f /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "rm -f /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "test -e /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(1);

			result = runShell(container, "update-ca-certificates");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "test -f /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(0);
		}
	}

	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(DebianFlavours.class)
	void keystoreNotRecreatedWhenUpdatesDisabled(String distribution, String codename) {
		Path hostDeb = DebFiles.hostDebPath();
		assertThat(hostDeb).exists();
		File containerDeb = new File("", hostDeb.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostDeb), containerDeb.toString())
				.start();

			Container.ExecResult result;

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get update");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + containerDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "test -f /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "rm -f /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "test -e /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(1);

			result = runShell(container, "echo \"cacerts_updates=no\" > /etc/default/adoptium-ca-certificates");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "update-ca-certificates");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "test -e /etc/ssl/certs/adoptium/cacerts");
			assertThat(result.getExitCode()).isEqualTo(1);
		}
	}

	@ParameterizedTest(name = "{0}:{1}")
	@ArgumentsSource(DebianFlavours.class)
	void newlyCreatedCertificateAddedToKeystore(String distribution, String codename) {
		Path hostDeb = DebFiles.hostDebPath();
		assertThat(hostDeb).exists();
		File containerDeb = new File("", hostDeb.toFile().getName());

		try (GenericContainer<?> container = new GenericContainer<>(String.format("%s:%s", distribution, codename))) {
			container.withCommand("/bin/bash", "-c", "while true; do sleep 10; done")
				.withCopyFileToContainer(MountableFile.forHostPath(hostDeb), containerDeb.toString())
				.start();

			Container.ExecResult result;

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get update");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y " + containerDeb);
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "DEBIAN_FRONTEND=noninteractive apt-get install -y default-jre");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(
				container, "keytool -list -keystore /etc/ssl/certs/adoptium/cacerts -storepass changeit"
			);
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.containsIgnoringCase("Keystore type: jks")
				.containsIgnoringCase("Keystore provider: SUN")
				.doesNotContain("adoptiumdummyca");

			result = runShell(container, "openssl req -x509 -newkey rsa:2048 -keyout key.pem -out " +
				"/usr/local/share/ca-certificates/cert.crt -days 365 -nodes -subj '/CN=Adoptium Dummy CA'");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(container, "update-ca-certificates");
			assertThat(result.getExitCode()).isEqualTo(0);

			result = runShell(
				container, "keytool -list -keystore /etc/ssl/certs/adoptium/cacerts -storepass changeit"
			);
			assertThat(result.getExitCode()).isEqualTo(0);
			assertThat(result.getStdout())
				.containsIgnoringCase("Keystore type: jks")
				.containsIgnoringCase("Keystore provider: SUN")
				.contains("adoptiumdummyca");
		}
	}
}
