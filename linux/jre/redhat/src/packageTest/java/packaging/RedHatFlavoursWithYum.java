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
		/*
		 * Amazon Linux: All supported versions until long-term support runs out
		 *     (https://aws.amazon.com/amazon-linux-2/faqs/).
		 * CentOS: Remove 7 once there are no more maintenance updates provided
		 *     (https://wiki.centos.org/About/Product), expected 2024-06-30.
		 * Oracle Linux: All supported versions until premier support runs out
		 *     (https://www.oracle.com/a/ocom/docs/elsp-lifetime-069338.pdf)
		 */
		return Stream.of(
			Arguments.of("amazonlinux", "2"),
			Arguments.of("centos", "7"),
			Arguments.of("registry.access.redhat.com/ubi7/ubi", "latest"),
			Arguments.of("oraclelinux", "7")
		);
	}
}
