package net.adoptopenjdk.installer;

import java.util.Collection;
import java.util.StringJoiner;

class StringUtils {

    private StringUtils() {
        // no instances
    }

    static String join(String separator, Collection<String> elements) {
        StringJoiner joiner = new StringJoiner(separator);
        for (String element : elements) {
            joiner.add(element);
        }
        return joiner.toString();
    }
}
