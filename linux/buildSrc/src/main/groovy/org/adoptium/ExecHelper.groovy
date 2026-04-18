package org.adoptium

import javax.inject.Inject
import org.gradle.process.ExecOperations

// Helper class for Gradle 9.x compatible exec operations
abstract class ExecHelper {
	@Inject
	abstract ExecOperations getExecOperations()

	void exec(Closure closure) {
		execOperations.exec(closure)
	}
}
