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
 * Provides the name and versions of container images using Red Hat flavours that the packages should be tested against
 * and that use dnf as package manager.
 * <p/>
 * {@link RedHatFlavoursWithYum} takes care of Red Hat flavours that use yum as package manager.
 *
 * @see RedHatFlavoursWithYum
 * @author Andreas Ahlenstorf
 */
public class RedHatFlavoursWithDnf implements ArgumentsProvider {
	@Override
	public Stream<? extends Arguments> provideArguments(ExtensionContext context) {
		/*
		 * Rocky Linux (CentOS replacement): All supported versions
		 * Oracle Linux: All supported versions until premier support runs out
		 *     (https://www.oracle.com/a/ocom/docs/elsp-lifetime-069338.pdf)
		 * Amazon Linux2 does not support DNF but only Yum
		 * ubi7 does not have DNF pre-installed, ubi-minimal has microdnf
		 * ubi8 has DNF installed
		 */

		String containerRegistry = "";

		if (System.getenv("containerRegistry") == null) { 
			System.out.println("Using docker.io as the default container registry");
		} else {
			containerRegistry = System.getenv("containerRegistry");
			System.out.println("Using container registry: " + containerRegistry);
		}

		return Stream.of(
			Arguments.of(containerRegistry + "rockylinux", "8"),
			Arguments.of(containerRegistry + "fedora", "35"),
			Arguments.of(containerRegistry + "fedora", "36"),
			Arguments.of(containerRegistry + "fedora", "37"),
			Arguments.of(containerRegistry + "fedora", "38"),
			Arguments.of(containerRegistry + "fedora", "39"),
			Arguments.of(containerRegistry + "redhat/ubi8", "latest"),
			Arguments.of(containerRegistry + "redhat/ubi9", "latest"),
			Arguments.of(containerRegistry + "oraclelinux", "8")
		);
	}
}
