FROM cimg/android:2026.03.1

# ---- fvm + Flutter 3.44.4 (fvm-managed) ----
# Install fvm via the standalone install script (no pre-existing Dart needed).
# The script drops the binary in ~/fvm/bin; put it on PATH for later layers.
RUN curl -fsSL https://fvm.app/install.sh | bash
ENV PATH="/home/circleci/fvm/bin:${PATH}"

# Cache the .fvmrc-pinned SDK inside the image so `fvm install` in CI is a no-op
# (no per-pipeline download). `fvm global` publishes a `default` symlink so plain
# `flutter` on PATH also resolves to the same pinned SDK.
RUN fvm install 3.44.4 --setup \
 && fvm global 3.44.4
ENV PATH="/home/circleci/fvm/default/bin:${PATH}"
RUN flutter precache --android --no-web --no-linux --no-windows --no-fuchsia --no-ios --no-macos

# ---- 系統工具（含 ninja 備援）----
RUN sudo apt-get update \
 && sudo apt-get install -y ruby ruby-dev rubygems ninja-build \
 && sudo rm -rf /var/lib/apt/lists/*
ENV GEM_HOME="/home/circleci/.gem"
ENV PATH="/home/circleci/.gem/bin:${PATH}"
RUN mkdir -p "/home/circleci/.gem" && sudo chown -R "$(whoami)" "/home/circleci/.gem"
RUN gem install bundler -NV

# ---- Android SDK 路徑（沿用 base image 真實路徑）----
ENV ANDROID_SDK_ROOT=/home/circleci/android-sdk
ENV ANDROID_HOME=/home/circleci/android-sdk
ENV PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/cmake/3.22.1/bin:${PATH}"

# ---- 接受授權並安裝 CMake / API 35 / Build-Tools 35 ----
RUN yes | sdkmanager --licenses >/dev/null || true
RUN sdkmanager "platform-tools" "cmake;3.22.1" "platforms;android-35" "build-tools;35.0.0"

# ---- 建立相容 symlink（給仍依賴 /opt/android/sdk 的流程）----
USER root
RUN mkdir -p /opt/android && ln -sfn /home/circleci/android-sdk /opt/android/sdk
USER circleci

# ---- 驗證 fvm 與 flutter 皆可用且為 3.44.4 ----
RUN fvm --version && fvm flutter --version && flutter --version
