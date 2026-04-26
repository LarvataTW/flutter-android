# 以 CircleCI 官方 Android 映像為基底，內含常用 Android/CI 工具。
FROM cimg/android:2026.03.1

# Flutter 版本（下載與安裝時使用）。
ARG FLUTTER_VERSION=3.35.0
# Android SDK 平台版本（提供對應 API level）。
ARG ANDROID_PLATFORM=android-35
# Android Build Tools 版本（Gradle/Android build 需要）。
ARG BUILD_TOOLS_VERSION=35.0.0
# CMake 版本（原生模組編譯會用到）。
ARG CMAKE_VERSION=3.22.1
ARG CMDLINE_TOOLS_VERSION=11076708
# Temurin JDK 21 下載網址（手動安裝固定 JDK 版本）。
ARG TEMURIN_URL="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.10%2B7/OpenJDK21U-jdk_x64_linux_hotspot_21.0.10_7.tar.gz"

# 設定環境變數：
# 1) 將 Flutter bin 加入 PATH
# 2) 設定 Ruby gem 安裝目錄
# 3) 指定 Java 安裝位置
# 4) 指定 Android SDK 位置
ENV PATH="/home/circleci/flutter/bin:${PATH}" \
    GEM_HOME="/home/circleci/.gem" \
    JAVA_HOME="/opt/java/openjdk" \
    ANDROID_SDK_ROOT=/opt/android/sdk \
    ANDROID_HOME=/opt/android/sdk
# 追加 PATH，確保 Java / gem / sdkmanager / cmake 指令可直接使用。
ENV PATH="$JAVA_HOME/bin:/home/circleci/.gem/bin:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/cmake/${CMAKE_VERSION}/bin:${PATH}"

# 安裝 Temurin JDK 21：
# 1) 建立 Java 安裝目錄
# 2) 下載 JDK 壓縮檔
# 3) 解壓到 /opt/java
# 4) 刪除暫存壓縮檔
# 5) 建立固定符號連結 /opt/java/openjdk
# 6) 驗證 java 版本
RUN sudo mkdir -p /opt/java \
 && sudo wget -qO /tmp/temurin-jdk.tar.gz "${TEMURIN_URL}" \
 && sudo tar -xzf /tmp/temurin-jdk.tar.gz -C /opt/java \
 && sudo rm -f /tmp/temurin-jdk.tar.gz \
 && sudo ln -sfn /opt/java/jdk-21.0.10+7 /opt/java/openjdk \
 && java -version

# 安裝 Flutter SDK：
# 1) 下載指定版本 Flutter
# 2) 解壓到使用者家目錄
# 3) 刪除下載檔
# 4) 關閉 Flutter analytics
# 5) 只預先快取 Android 所需 artifacts（排除其他平台）
RUN wget -q "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && tar xf "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" -C "${HOME}" \
 && rm -f "flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && "${HOME}/flutter/bin/flutter" config --no-analytics \
 && "${HOME}/flutter/bin/flutter" precache --android --no-web --no-linux --no-windows --no-fuchsia --no-ios --no-macos

# 安裝系統套件：
# 1) 更新 apt 索引
# 2) 安裝 Ruby / Ruby 開發套件 / RubyGems / Ninja
# 3) 清理 apt 快取以縮小映像
RUN sudo apt-get update \
 && sudo apt-get install -y --no-install-recommends ruby ruby-dev rubygems ninja-build unzip \
 && sudo rm -rf /var/lib/apt/lists/*

# Fastlane 版本（預裝進 image，CI cache miss 時可從本地 gem cache 複製，不必重新下載）。
ARG FASTLANE_VERSION=2.233.0

# 設定 Ruby gem 環境：
# 1) 建立 GEM_HOME 目錄
# 2) 修正目錄擁有者，避免權限問題
# 3) 安裝 bundler（-N 不安裝文件）
# 4) 預裝 fastlane，讓 .gem 檔案快取到 GEM_HOME/cache/
#    之後 bundle install --path vendor/bundle 時，bundler 優先從本地快取複製，
#    不需從 rubygems.org 重新下載，cache miss 情況下可節省 1-2 分鐘。
RUN mkdir -p "${GEM_HOME}" \
 && sudo chown -R "$(whoami)" "${GEM_HOME}" \
 && gem install bundler -N \
 && gem install fastlane -v "${FASTLANE_VERSION}" -N

# 安裝 Android SDK（固定到 /opt/android/sdk）：
# 1) 建立 SDK 目錄並修正權限
# 2) 下載 commandline-tools 並放到 cmdline-tools/latest
# 3) 接受授權並安裝必要元件
# 4) 驗證關鍵目錄存在
RUN sudo mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
 && sudo chown -R "$(whoami)" /opt/android \
 && wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip" -O /tmp/cmdline-tools.zip \
 && rm -rf "${ANDROID_SDK_ROOT}/cmdline-tools/latest" "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" \
 && unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_SDK_ROOT}/cmdline-tools" \
 && mv "${ANDROID_SDK_ROOT}/cmdline-tools/cmdline-tools" "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
 && rm -f /tmp/cmdline-tools.zip \
 && yes | sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" --licenses >/dev/null || true \
 && sdkmanager --sdk_root="${ANDROID_SDK_ROOT}" \
    "platform-tools" \
    "platforms;${ANDROID_PLATFORM}" \
    "build-tools;${BUILD_TOOLS_VERSION}" \
    "cmake;${CMAKE_VERSION}" \
 && test -x "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager" \
 && test -d "${ANDROID_SDK_ROOT}/platform-tools" \
 && test -d "${ANDROID_SDK_ROOT}/build-tools/${BUILD_TOOLS_VERSION}"

# 暫時切到 root 進行系統層級路徑調整。
USER root
# 相容舊路徑：
# 1) 移除舊的 /home/circleci/android-sdk
# 2) 建立連到 /opt/android/sdk 的符號連結
RUN rm -rf /home/circleci/android-sdk \
 && ln -s /opt/android/sdk /home/circleci/android-sdk \
 && test -L /home/circleci/android-sdk \
 && test -d /opt/android/sdk
# 切回一般使用者，符合 CI 執行慣例。
USER circleci
