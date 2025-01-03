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

import org.testcontainers.containers.Container;

import java.io.IOException;

/**
 * @author Andreas Ahlenstorf
 */
public final class TestContainersUtil {
	private TestContainersUtil() {
		// no instances
	}

	public static Container.ExecResult runCmd(Container<?> container, String... command) {
		try {
			Container.ExecResult result = container.execInContainer(command);
			System.out.print(result.getStdout());
			System.err.print(result.getStderr());
			return result;
		} catch (InterruptedException | IOException e) {
			throw new RuntimeException("Could not run command: " + String.join(" ", command), e);
		}
	}

	public static Container.ExecResult runShell(Container<?> container, String command) {
		String[] shellCmd = new String[]{"/bin/bash", "-c", command};
		try {
			Container.ExecResult result = container.execInContainer(shellCmd);
			System.out.print(result.getStdout());
			System.err.print(result.getStderr());
			return result;
		} catch (InterruptedException | IOException e) {
			throw new RuntimeException("Could not run command: " + String.join(" ", shellCmd), e);
		}
	}
}
