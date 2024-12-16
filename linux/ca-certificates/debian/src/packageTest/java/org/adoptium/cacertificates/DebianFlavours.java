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

import org.junit.jupiter.api.extension.ExtensionContext;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.ArgumentsProvider;

import java.util.stream.Stream;

/**
 * @author Andreas Ahlenstorf
 */
public class DebianFlavours implements ArgumentsProvider {
	@Override
	public Stream<? extends Arguments> provideArguments(ExtensionContext context) {
		/*
		 * Debian policy: oldstable, stable and testing version.
		 *     (https://www.debian.org/releases/)
		 * Ubuntu policy: Current LTS versions, and development version.
		 *     (https://wiki.ubuntu.com/Releases)
		 */

		String containerRegistry = "";

		if (System.getenv("containerRegistry") == null) {
			System.out.println("Using docker.io as the default container registry");
		} else {
			containerRegistry = System.getenv("containerRegistry");
			System.out.println("Using container registry: " + containerRegistry);
		}

		return Stream.of(
		  	Arguments.of(containerRegistry + "debian", "trixie"),   // Debian/13 (testing)
			Arguments.of(containerRegistry + "debian", "bookworm"), // Debian/12 (testing)
			Arguments.of(containerRegistry + "debian", "bullseye"), // Debian/11 (stable)
			Arguments.of(containerRegistry + "debian", "buster"),   // Debian/10 (oldstable)
			Arguments.of(containerRegistry + "ubuntu", "oracular"), // Ubuntu/24.10 (STS)
			Arguments.of(containerRegistry + "ubuntu", "noble"),    // Ubuntu/24.04 (LTS)
			Arguments.of(containerRegistry + "ubuntu", "jammy"),    // Ubuntu/22.04 (LTS)
			Arguments.of(containerRegistry + "ubuntu", "focal"),    // Ubuntu/20.04 (LTS)
			Arguments.of(containerRegistry + "ubuntu", "bionic")    // Ubuntu/18.04 (LTS)
		);
	}
}
