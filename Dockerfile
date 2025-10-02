FROM cimg/android:2023.06
ENV PATH="/home/circleci/flutter/bin:${PATH}"
# Install and pre-cache Flutter.
RUN wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.32.0-stable.tar.xz && \
  tar xf flutter_linux_3.32.0-stable.tar.xz -C ${HOME} && \
  rm flutter_linux_3.32.0-stable.tar.xz

RUN ${HOME}/flutter/bin/flutter precache --no-web --no-linux --no-windows --no-fuchsia --no-ios --no-macos
RUN sudo apt update
RUN sudo apt install -y ruby ruby-dev rubygems ninja-build \
  && sudo rm -rf /var/lib/apt/lists/*
ENV GEM_HOME="/home/circleci/.gem"
ENV PATH="/home/circleci/.gem/bin:${PATH}"
RUN mkdir -p "/home/circleci/.gem"
RUN sudo chown -R "$(whoami)" "/home/circleci/.gem"
# Install bundler.
RUN gem install bundler -NV

# ---- Android SDK components (CMake only; do NOT install or pin any NDK here) ----
cimg/android has ANDROID_SDK_ROOT preset (usually /opt/android/sdk)
RUN yes | sdkmanager --licenses
RUN sdkmanager "platform-tools" "cmake;3.22.1"

# (Intentionally NOT adding a specific cmake bin to PATH to keep image generic)
# Ninja will be found via system 'ninja' from apt (ninja-build).
