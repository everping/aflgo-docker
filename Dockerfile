FROM ubuntu:16.04

WORKDIR /fuzzing/

RUN apt-get update -qq
RUN	apt-get install -y build-essential make cmake ninja-build git subversion python2.7 binutils-gold binutils-dev python3 python3-dev python3-pip autoconf libtool pkg-config wget gawk

RUN mkdir -p chromium_tools && cd chromium_tools && git clone https://chromium.googlesource.com/chromium/src/tools/clang
RUN cd chromium_tools/clang && export LLVM_REVISION=$(grep -Po "CLANG_REVISION = '\K\d+(?=')" scripts/update.py) && echo "Using LLVM revision: $LLVM_REVISION"
	
RUN wget http://releases.llvm.org/4.0.0/llvm-4.0.0.src.tar.xz
RUN wget http://releases.llvm.org/4.0.0/cfe-4.0.0.src.tar.xz
RUN wget http://releases.llvm.org/4.0.0/compiler-rt-4.0.0.src.tar.xz
RUN wget http://releases.llvm.org/4.0.0/libcxx-4.0.0.src.tar.xz
RUN wget http://releases.llvm.org/4.0.0/libcxxabi-4.0.0.src.tar.xz

RUN	tar xf llvm-4.0.0.src.tar.xz
RUN	tar xf cfe-4.0.0.src.tar.xz
RUN	tar xf compiler-rt-4.0.0.src.tar.xz
RUN	tar xf libcxx-4.0.0.src.tar.xz
RUN	tar xf libcxxabi-4.0.0.src.tar.xz

RUN rm -rf *.src.tar.xz
	
RUN mv cfe-4.0.0.src llvm-4.0.0.src/tools/clang
RUN mv compiler-rt-4.0.0.src llvm-4.0.0.src/projects/compiler-rt
RUN mv libcxx-4.0.0.src llvm-4.0.0.src/projects/libcxx
RUN mv libcxxabi-4.0.0.src llvm-4.0.0.src/projects/libcxxabi

RUN mkdir -p build-llvm/llvm && cd build-llvm/llvm && cmake -G "Ninja" -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="X86" -DLLVM_BINUTILS_INCDIR=/usr/include ../../llvm-4.0.0.src && ninja && ninja install

RUN	mkdir -p build-llvm/msan && cd build-llvm/msan && cmake -G "Ninja" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ -DLLVM_USE_SANITIZER=Memory -DCMAKE_INSTALL_PREFIX=/usr/msan/ -DLIBCXX_ENABLE_SHARED=OFF -DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD="X86" ../../llvm-4.0.0.src && ninja cxx && ninja install-cxx

RUN git clone https://chromium.googlesource.com/chromium/llvm-project/llvm/lib/Fuzzer libfuzzer

RUN cp llvm-4.0.0.src/tools/sancov/coverage-report-server.py /usr/local/bin/

# Install LLVMgold into bfd-plugins
RUN mkdir -p /usr/lib/bfd-plugins
RUN cp /usr/local/lib/libLTO.so /usr/lib/bfd-plugins
RUN cp /usr/local/lib/LLVMgold.so /usr/lib/bfd-plugins

RUN pip3 install --upgrade pip
RUN pip3 install networkx
RUN pip3 install pydot
RUN pip3 install pydotplus

ENV ROOT_FUZZING=/fuzzing
ENV AFLGO=$ROOT_FUZZING/aflgo

ENV SUBJECT=$ROOT_FUZZING/libxml2
ENV TMP_DIR=$ROOT_FUZZING/temp
ENV RUN_DIR=$ROOT_FUZZING/in

RUN mkdir -p $TMP_DIR

RUN git clone https://github.com/aflgo/aflgo.git
RUN cd $AFLGO && make clean all && cd $AFLGO/llvm_mode && make clean all

RUN git clone https://gitlab.gnome.org/GNOME/libxml2.git
RUN wget https://raw.githubusercontent.com/jay/showlinenum/develop/showlinenum.awk
RUN chmod +x showlinenum.awk
RUN mv showlinenum.awk $TMP_DIR

ENV CC=$AFLGO/afl-clang-fast
ENV CXX=$AFLGO/afl-clang-fast++
ENV COPY_CFLAGS=$CFLAGS
ENV COPY_CXXFLAGS=$CXXFLAGS
ENV ADDITIONAL="-targets=$TMP_DIR/BBtargets.txt -outdir=$TMP_DIR -flto -fuse-ld=gold -Wl,-plugin-opt=save-temps"
ENV CFLAGS="$CFLAGS $ADDITIONAL"
ENV CXXFLAGS="$CXXFLAGS $ADDITIONAL"
ENV LDFLAGS=-lpthread
COPY fuzz.sh /fuzzing/

RUN chmod +x fuzz.sh
ENTRYPOINT ["./fuzz.sh"]
