FROM crystallang/crystal:1.14-alpine

# Set environment variables to non-interactive to avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

RUN apk update && apk add --no-cache \
    sqlite-dev \
    xz-dev

# Set the working directory
WORKDIR /app

# copy project files
COPY . /app

RUN shards install
RUN crystal build src/turnir.cr -o turnir.bin --error-trace

# start app
CMD ["/app/turnir.bin"]
