FROM cimg/android:2021.12
ENV PATH="/home/circleci/flutter/bin:${PATH}"
# Install and pre-cache Flutter.
RUN wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.3.10-stable.tar.xz && \
  tar xf flutter_linux_3.3.10-stable.tar.xz -C ${HOME} && \
  rm flutter_linux_3.3.10-stable.tar.xz

RUN ${HOME}/flutter/bin/flutter precache --no-web --no-linux --no-windows --no-fuchsia --no-ios --no-macos
RUN sudo apt update
RUN sudo apt install -y ruby ruby-dev rubygems \
  && sudo rm -rf /var/lib/apt/lists/*
# Install bundler.
RUN sudo gem install bundler -NV