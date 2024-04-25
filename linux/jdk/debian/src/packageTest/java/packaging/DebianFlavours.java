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
 * @author luozhenyu
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
        return Stream.of(
                Arguments.of("debian", "trixie"),   // Debian/13 (testing)
                Arguments.of("debian", "bookworm"), // Debian/12 (testing)
                Arguments.of("debian", "bullseye"), // Debian/11 (stable)
                Arguments.of("debian", "buster"),   // Debian/10 (oldstable)
                Arguments.of("ubuntu", "noble"),    // Ubuntu/24.04 (LTS)
                Arguments.of("ubuntu", "jammy"),    // Ubuntu/22.04 (LTS)
                Arguments.of("ubuntu", "focal"),    // Ubuntu/20.04 (LTS)
                Arguments.of("ubuntu", "bionic")    // Ubuntu/18.04 (LTS)
        );
    }
}
