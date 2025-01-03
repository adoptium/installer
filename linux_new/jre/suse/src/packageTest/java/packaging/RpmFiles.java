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

import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

/**
 * Utility methods to interact with rpm files.
 *
 * @author Andreas Ahlenstorf
 */
final class RpmFiles {
	private RpmFiles() {
		// no instances
	}

	static Path hostRpmPath() {
		// convert filter when build with ARCH == all, only test on x86_64
		String rpmFilter = "";
		if (System.getenv("testArch").equals("all")) {
			rpmFilter = System.getenv("PACKAGE") + "*.x86_64.rpm";
		} else {
			rpmFilter = System.getenv("PACKAGE") + "*." + System.getenv("testArch") + ".rpm";
		}
		System.out.println(rpmFilter);
		return findBuildOutputOnHost(rpmFilter);
	}

	private static Path findBuildOutputOnHost(String pattern) {
		Path outputDirectory = Paths.get("build", "ospackage"); // same as in container /home/builder/out
		try (DirectoryStream<Path> stream = Files.newDirectoryStream(outputDirectory, pattern)) {
			for (Path candidateFile : stream) {
				return candidateFile;
			}
		} catch (IOException x) {
			throw new UncheckedIOException(x);
		}

		throw new RuntimeException("Could not find file with pattern " + pattern + " in " + outputDirectory.toString());
	}
}
