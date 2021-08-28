FROM cimg/android:29.0
ENV PATH="/home/circleci/flutter/bin:${PATH}"
# Install and pre-cache Flutter.
RUN wget https://storage.googleapis.com/flutter_infra/releases/stable/linux/flutter_linux_1.22.6-stable.tar.xz && \
  tar xf flutter_linux_1.22.6-stable.tar.xz -C ${HOME} && \
  rm flutter_linux_1.22.6-stable.tar.xz

RUN ${HOME}/flutter/bin/flutter precache --no-web --no-linux --no-windows --no-fuchsia --no-ios --no-macos
RUN sudo apt update
RUN sudo apt install -y ruby ruby-dev rubygems
# Install bundler.
RUN sudo gem install bundler -NV