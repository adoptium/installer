package net.adoptopenjdk.installer.bintray;

class BintrayClientException extends RuntimeException {
    BintrayClientException(String message) {
        super(message);
    }

    BintrayClientException(String message, Throwable cause) {
        super(message, cause);
    }
}
