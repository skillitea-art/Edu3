FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    curl \
    unzip \
    wget \
    zip \
    xz-utils \
    libglu1-mesa \
    openjdk-21-jdk \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev \
    && apt-get clean

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV PATH=$JAVA_HOME/bin:$PATH