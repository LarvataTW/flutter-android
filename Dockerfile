FROM cimg/android:2026.03.1

# ---- Flutter 3.44.4 ----
ENV PATH="/home/circleci/flutter/bin:${PATH}"
RUN wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.4-stable.tar.xz \
 && tar xf flutter_linux_3.44.4-stable.tar.xz -C ${HOME} \
 && rm -f flutter_linux_3.44.4-stable.tar.xz
RUN ${HOME}/flutter/bin/flutter precache --android --no-web --no-linux --no-windows --no-fuchsia --no-ios --no-macos

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
