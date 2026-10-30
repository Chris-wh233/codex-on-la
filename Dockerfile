FROM lcr.loongnix.cn/openeuler/openeuler:24.03-LTS-SP4

RUN dnf install -y git wget curl \
      cmake python3 ninja-build \
      pkg-config glib2-devel \
      libcap-devel \
      llvm-toolset-21 \
      go libstdc++-static \
      protobuf-compiler \
      openssl-devel \
    && ln -sf /usr/bin/clang-21 /usr/bin/clang \
    && ln -sf /usr/bin/clang++-21 /usr/bin/clang++

RUN curl --proto '=https' --tlsv1.2 -sSf \
      --retry 5 --retry-delay 2 --retry-all-errors \
      -o /tmp/rustup-init.sh https://sh.rustup.rs \
    && sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain 1.95.0 \
    && rm -f /tmp/rustup-init.sh

ENV PATH=/root/.cargo/bin:$PATH

RUN cargo install bindgen-cli \
    && cargo install --locked --version 15.2.0 ripgrep \
    && strip --strip-unneeded /root/.cargo/bin/rg

CMD ["/bin/bash"]
