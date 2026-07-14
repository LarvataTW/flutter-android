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
 && sudo apt-get install -y ruby ruby-dev rubygems ninja-build unzip \
 && sudo rm -rf /var/lib/apt/lists/*
ENV GEM_HOME="/home/circleci/.gem"
ENV PATH="/home/circleci/.gem/bin:${PATH}"
RUN mkdir -p "/home/circleci/.gem" && sudo chown -R "$(whoami)" "/home/circleci/.gem"
RUN gem install bundler:4.0.3 -NV

# ---- (§1) 烘焙 root Gemfile 的 gems（fastlane / cocoapods / xcodeproj / firebase 外掛）----
# 對應 flutter-template docs/flutter-template/android-image/android-image-v5-plan.md §1。
# CI 端 Android job 已移除 `bundle config set path vendor/bundle`（改用系統 BUNDLE_PATH），
# 所以 job 內的 `cd android && bundle install` 會命中這裡烘焙好的 gems，免每個 job 重裝。
# 固定一份 template 的 Gemfile.lock 快照（bundler 4.0.3 / fastlane 2.236.1 /
# cocoapods 1.10.2）；template 日後 bump gem 時，CI 的 bundle install 會 fail-soft 裝差量。
ENV BUNDLE_PATH="/home/circleci/.bundle" \
    BUNDLE_APP_CONFIG="/home/circleci/.bundle"
COPY --chown=circleci:circleci Gemfile Gemfile.lock /tmp/gems/
RUN cd /tmp/gems \
 && bundle _4.0.3_ install --jobs 4 \
 && sudo rm -rf /tmp/gems

# ---- Android SDK 路徑（沿用 base image 真實路徑）----
ENV ANDROID_SDK_ROOT=/home/circleci/android-sdk
ENV ANDROID_HOME=/home/circleci/android-sdk
ENV PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/cmake/3.22.1/bin:${PATH}"

# ---- 接受授權並安裝 CMake / API 35 / Build-Tools 35 ----
RUN yes | sdkmanager --licenses >/dev/null || true
RUN sdkmanager "platform-tools" "cmake;3.22.1" "platforms;android-35" "build-tools;35.0.0"

# ---- (§3a) 預熱 Gradle wrapper distribution（消除每個 build 重抓 gradle-8.12-all.zip ~200MB）----
# 對應 v5 plan §3。用一個指向 gradle-8.12-all.zip 的 wrapper 跑一次 gradlew，讓 wrapper 用它
# 自己的雜湊規則把 distribution 解壓到 $GRADLE_USER_HOME/wrapper/dists/…。template 的
# android/gradle/wrapper/gradle-wrapper.properties 用完全相同的 distributionUrl，雜湊一致
# → CI build 直接命中，不再下載。（§3b 完整 AGP 相依圖需 build 時取得 template 專案，牽涉
# 私有 repo 認證，留待後續；此處先消除最大宗的 distribution 下載。）
ENV GRADLE_USER_HOME="/home/circleci/.gradle"
RUN cd /tmp \
 && wget -q https://services.gradle.org/distributions/gradle-8.12-bin.zip \
 && unzip -q gradle-8.12-bin.zip \
 && mkdir -p /tmp/gwarm && cd /tmp/gwarm \
 && /tmp/gradle-8.12/bin/gradle wrapper --gradle-version 8.12 --distribution-type all \
 && ./gradlew --version \
 && cd / && rm -rf /tmp/gwarm /tmp/gradle-8.12 /tmp/gradle-8.12-bin.zip

# ---- (§4) coverage：lcov_cobertura（CI unit_widget 把 lcov.info 轉成 cobertura.xml）----
# 對應 v5 plan §4；補齊 .gitlab-ci.yml 宣告卻從未產生的 coverage/cobertura.xml。
RUN sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends python3-pip \
 && sudo pip3 install --no-cache-dir --break-system-packages lcov_cobertura \
 && sudo rm -rf /var/lib/apt/lists/*

# ---- 建立相容 symlink（給仍依賴 /opt/android/sdk 的流程）----
USER root
RUN mkdir -p /opt/android && ln -sfn /home/circleci/android-sdk /opt/android/sdk
USER circleci

# ---- 驗證 fvm 與 flutter 皆可用且為 3.44.4 ----
RUN fvm --version && fvm flutter --version && flutter --version
