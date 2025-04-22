# Use ARG to easily change the Postgres version
ARG PG_MAJOR=15
ARG DEBIAN_FRONTEND=noninteractive

# ---- FFI Artifact Builder Stage ----
# Build the hessra-ffi shared library and header file
FROM rust:1.86-slim-bullseye AS ffi-builder

WORKDIR /app

# Copy the FFI wrapper crate source
# Path is relative to the build context (postgres-plugin/)
COPY ./hessra-ffi-wrapper ./hessra-ffi-wrapper

# Build the shared library and generate the header
WORKDIR /app/hessra-ffi-wrapper
RUN cargo build --release

# Build the C extension using artifacts from ffi-builder
FROM debian:bullseye AS plugin-builder

ARG PG_MAJOR
ARG DEBIAN_FRONTEND

# Install build dependencies (Postgres dev, C tools)
# Updated sequence to potentially fix GPG signature issues
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    lsb-release && \
    # Update certificates - might help with GPG issues
    # update-ca-certificates ## Debian maintainer scripts handle this
    # Fetch the PostgreSQL GPG key and store it securely
    curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgresql-archive-keyring.gpg && \
    # Add the PostgreSQL repository using the signed-by option
    echo "deb [signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    # Update package lists again to include the new repository
    apt-get update && \
    # Install remaining build dependencies
    apt-get install -y --no-install-recommends \
    build-essential \
    # Add common dev libraries that Postgres might link against
    libxml2-dev \
    libssl-dev \
    libkrb5-dev \
    zlib1g-dev \
    libreadline-dev \
    # Install Postgres dev headers and pg_config
    postgresql-server-dev-${PG_MAJOR} \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy C plugin source code
COPY . .

# Copy artifacts from the FFI builder stage
COPY --from=ffi-builder /app/hessra-ffi-wrapper/target/release/libhessra_ffi.so .
COPY --from=ffi-builder /app/hessra-ffi-wrapper/include/hessra_ffi.h .

# Build the C extension (Makefile assumes .so and .h are in current dir)
RUN make FFI_BUILD_PROFILE=release # Profile not strictly needed by make now, but harmless

# Display the contents of the include directory to verify the header file is there
RUN ls -la .
RUN cat hessra_ffi.h | head -20

# ---- Runtime Stage ----
FROM postgres:${PG_MAJOR}-bullseye

ARG PG_MAJOR

# Install binutils for debugging
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    binutils \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy build artifacts from the plugin-builder stage
# The .so file is named based on the MODULES variable in the Makefile
COPY --from=plugin-builder /build/hessra_authz.so /usr/lib/postgresql/${PG_MAJOR}/lib/
COPY --from=plugin-builder /build/libhessra_ffi.so /usr/lib/
COPY --from=plugin-builder /build/hessra_authz.control /usr/share/postgresql/${PG_MAJOR}/extension/
COPY --from=plugin-builder /build/hessra_authz--0.1.0.sql /usr/share/postgresql/${PG_MAJOR}/extension/

# Create a wrapper script for postgres to preload the library
RUN echo '#!/bin/bash\nexport LD_PRELOAD=/usr/lib/libhessra_ffi.so\nexec "$@"' > /usr/local/bin/postgres-wrapper && \
    chmod +x /usr/local/bin/postgres-wrapper

# Use the wrapper as the entrypoint
ENTRYPOINT ["/usr/local/bin/postgres-wrapper", "docker-entrypoint.sh"]
CMD ["postgres"] 