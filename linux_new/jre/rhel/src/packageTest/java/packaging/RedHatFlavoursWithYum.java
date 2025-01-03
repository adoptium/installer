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
 * and that use yum as package manager.
 * <p/>
 * {@link RedHatFlavoursWithDnf} takes care of Red Hat flavours that use dnf as package manager.
 *
 * @see RedHatFlavoursWithDnf
 * @author Andreas Ahlenstorf
 */
public class RedHatFlavoursWithYum implements ArgumentsProvider {
	@Override
	public Stream<? extends Arguments> provideArguments(ExtensionContext context) {
		// get arch with only alphanumeric chars
		String normalized_arch = System.getProperty("os.arch").toLowerCase().replaceAll("[^a-z0-9]+", "");
		boolean ubi7_supported = "x8664".equalsIgnoreCase(normalized_arch) || "amd64".equalsIgnoreCase(normalized_arch) || "ppc64le".equalsIgnoreCase(normalized_arch) || "s390x".equalsIgnoreCase(normalized_arch);
		Stream.Builder<Arguments> builder = Stream.builder();
		/*
		 * Amazon Linux: All supported versions until long-term support runs out
		 *     (https://aws.amazon.com/amazon-linux-2/faqs/).
		 * CentOS: Remove 7 once there are no more maintenance updates provided
		 *     (https://wiki.centos.org/About/Product), expected 2024-06-30.
		 * Oracle Linux: All supported versions until premier support runs out
		 *     (https://www.oracle.com/a/ocom/docs/elsp-lifetime-069338.pdf)
		 */

		String redHatRegistry = "registry.access.redhat.com/";
		String containerRegistry = "";

		if (System.getenv("containerRegistry") == null) { 
			System.out.println("Using docker.io as the default container registry");
		} else {
			containerRegistry = System.getenv("containerRegistry");
			redHatRegistry = containerRegistry;
			System.out.println("Using container registry: " + containerRegistry);
		}

		builder.add(Arguments.of(containerRegistry + "amazonlinux", "2"));
		builder.add(Arguments.of(containerRegistry + "centos", "7"));
		builder.add(Arguments.of(containerRegistry + "oraclelinux", "7"));
		
		/*
		 * Redhat UBI7: Does not currently suport aarch64 architecture
		 *     (https://catalog.redhat.com/software/containers/ubi7/ubi/5c3592dcd70cc534b3a37814?container-tabs=technical-information).
		 */
		if (ubi7_supported) {
			builder.add(Arguments.of(redHatRegistry + "ubi7/ubi", "latest"));
		}
		
		return builder.build();
	}
}
