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
 * @author Andreas Ahlenstorf
 */
public class DebianFlavours implements ArgumentsProvider {
	@Override
	public Stream<? extends Arguments> provideArguments(ExtensionContext context) {
		/*
		 * Debian policy: Oldest, newest and development version.
		 * Ubuntu policy: Oldest LTS, newest LTS, and development version.
		 */
		return Stream.of(
			Arguments.of("debian", "stretch"),
			Arguments.of("debian", "buster"),
			Arguments.of("debian", "bullseye"),
			Arguments.of("ubuntu", "bionic"),
			Arguments.of("ubuntu", "focal"),
			Arguments.of("ubuntu", "impish")
		);
	}
}
