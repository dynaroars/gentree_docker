FROM ubuntu:focal-20201106

RUN apt-get update && \
    apt-get -y install sudo && \
    echo "kh ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers && \
    groupadd -g 1001 kh && \
    useradd -rm -d /home/kh -s /bin/bash -g kh -G sudo -u 1001 kh

USER kh
WORKDIR /home/kh

COPY --chown=kh:kh data /home/kh/data

RUN sudo mv ~/data/sources.list /etc/apt/ && \
    sudo apt-get update && \
    sudo ln -fs /usr/share/zoneinfo/America/Chicago /etc/localtime && \
    sudo apt-get -y install gcc-9 g++-9 wget curl git fish nano cmake && \
    sudo apt-get -y install build-essential libunwind-dev zlib1g-dev libjemalloc-dev && \
    sudo dpkg-reconfigure --frontend noninteractive tzdata

RUN cd ~ && \
    git clone https://github.com/unsat/gentree && \
    cd gentree && \
    git checkout submit_icse21 && \
    mkdir ~/cpplib && \
    cp -r third_party/build_scripts/. ~/cpplib && \
    cd ~/cpplib && \
    ./build.sh -p ~/cpplib/install -j 16 && \
    rm -rf ./*/_build*

RUN cd ~/gentree && \
    mkdir cmake-build-rdi && cd cmake-build-rdi && \
    cmake .. -DCMAKE_PREFIX_PATH=~/cpplib/install/ -DCMAKE_BUILD_TYPE=RelWithDebInfo && \
    make -j 15 && \
    cd .. && \
    mkdir cmake-build-debug && cd cmake-build-debug && \
    cmake .. -DCMAKE_PREFIX_PATH=~/cpplib/install/ -DCMAKE_BUILD_TYPE=Debug && \
    make -j 15 && \
    cd ../wd && \
    mv ~/data/je . && \
    ln -s ../cmake-build-rdi/igen4 gt && \
    ln -s ../cmake-build-rdi/kutil kutil && \
    ln -s ../cmake-build-debug/igen4 gt_debug

# RUN sudo apt-get install -y locales  && \
#     localedef -i en_US -f UTF-8 en_US.UTF-8 && \
#     sudo apt-get install -y --no-install-recommends ocaml-nox camlp4-extra opam m4 && \
#     opam init -a --disable-sandboxing && \
#     eval `opam env` && \
#     opam install -y bisect=1.3.1

RUN sudo apt-get install -y locales unzip m4 python rsync && \
    sudo apt-get install -y --no-install-recommends texlive-base && \
    sudo locale-gen "en_US.UTF-8" && \
    \
    bash -c 'echo | sh <(curl -sL https://raw.githubusercontent.com/ocaml/opam/8ce5e420f8007fd8d7ad56fb6293af6f5469a432/shell/install.sh)' && \
    opam init -a --disable-sandboxing --compiler=4.05.0 && \
    eval `opam env` && \
    opam install -y bisect=1.3.1

RUN printf "\nexit\n" | sudo cpan && \
    sudo cpan PJCJ/Devel-Cover-1.36.tar.gz

COPY --chown=kh:kh bench_progs /home/kh/bench_progs
RUN eval `opam env` && \
    cd ~/bench_progs/ocaml/unison-2.51.2 && \
    make && \
    cd ~/bench_progs/ocaml/bibtex2html-1.99 && \
    ./configure && \
    make
RUN cd ~/bench_progs/coreutils && \
    mkdir build && cd build && \
    ../coreutils-8.32/configure --disable-nls CFLAGS="-g -fprofile-arcs -ftest-coverage" && \
    make -j16 && \
    cd .. && \
    rsync -armv --include='*/' --include='*.gcno' --exclude='*' build/ cpy/

COPY --chown=kh:kh wd/res /home/kh/gentree/wd/res

COPY --chown=kh:kh wd/1 /home/kh/gentree/wd/1
COPY --chown=kh:kh wd/2 /home/kh/gentree/wd/2
RUN cd ~/gentree/wd/2 && \
    tar -xzvf testfiles.tar.gz

COPY --chown=kh:kh wd/build* wd/*.js /home/kh/gentree/wd/
COPY --chown=kh:kh wd/scripts /home/kh/gentree/wd/scripts
