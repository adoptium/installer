if [ $1 -eq 0 ]; then
    update-alternatives --remove java {{ prefix }}/{{ jdkDirectoryName }}/bin/java
    update-alternatives --remove javac {{ prefix }}/{{ jdkDirectoryName }}/bin/javac
fi
