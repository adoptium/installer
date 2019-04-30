package net.adoptopenjdk.installer.bintray;

class MessageJson {

    final String message;

    MessageJson(String message) {
        this.message = message;
    }

    @Override
    public String toString() {
        return "" + message;
    }
}
