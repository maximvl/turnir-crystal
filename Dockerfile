FROM debian:12-slim

# Set environment variables to non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y curl libsqlite3-dev liblzma-dev && \
    curl -fsSL https://crystal-lang.org/install.sh | bash


# crystal build src/turnir.cr -o bin/turnir.bin
