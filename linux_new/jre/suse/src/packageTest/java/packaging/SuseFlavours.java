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

package packaging;

import org.junit.jupiter.api.extension.ExtensionContext;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.ArgumentsProvider;

import java.util.stream.Stream;

/**
 * Provides the name and versions of container images using SUSE flavours that the packages should be tested against.
 *
 * @author Andreas Ahlenstorf
 */
public class SuseFlavours implements ArgumentsProvider {
	@Override
	public Stream<? extends Arguments> provideArguments(ExtensionContext context) {
		/*
		 * OpenSUSE: All supported versions, see https://en.opensuse.org/Lifetime.
		 * SLES: All supported versions, see https://www.suse.com/lifecycle.
		*/

		String suseRegistry = "registry.suse.com/";
		String containerRegistry = "";

		if (System.getenv("containerRegistry") == null) { 
			System.out.println("Using docker.io as the default container registry");
		} else {
			containerRegistry = System.getenv("containerRegistry");
			suseRegistry = containerRegistry;
			System.out.println("Using container registry: " + containerRegistry);
		}

		return Stream.of(
			Arguments.of(containerRegistry + "opensuse/leap", "15.3"),
			Arguments.of(containerRegistry + "opensuse/leap", "15.4"),
			Arguments.of(containerRegistry + "opensuse/leap", "15.5"),
			Arguments.of(suseRegistry + "suse/sles12sp5", "latest"),
			Arguments.of(suseRegistry + "suse/sle15", "latest")
		);
	}
}
