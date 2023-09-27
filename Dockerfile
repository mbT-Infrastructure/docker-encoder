FROM madebytimo/builder AS builder

RUN apt update -qq && apt install -y -qq libass-dev libopus-dev libmp3lame-dev \
    libvpx-dev libva-dev libvdpau-dev libvorbis-dev libx264-dev libx265-dev texinfo wget && \
    rm -rf /var/lib/apt/lists/*

RUN git clone --branch n6.0 --depth 1 https://github.com/FFmpeg/FFmpeg.git

RUN download.sh --name svt-av1.tar.gz \
    https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/master/SVT-AV1-master.tar.gz \
    && compress.sh --decompress svt-av1.tar.gz \
    && rm svt-av1.tar.gz \
    && mv SVT-AV1-master SVT-AV1 \
    && git -C FFmpeg am "$PWD/SVT-AV1/ffmpeg_plugin/n6.0"/*.patch

RUN cd SVT-AV1/Build \
    && cmake .. -G"Unix Makefiles" -DENABLE_AVX512=ON -DCMAKE_BUILD_TYPE=Release \
    && make --jobs "$(nproc)" \
    && make install

RUN mkdir FFmpeg/build \
    && cd FFmpeg/build \
    && ../configure --disable-doc --enable-gpl --enable-libass --enable-libfreetype \
    --enable-libmp3lame --enable-libopus --enable-libsvtav1 --enable-libvorbis --enable-libvpx \
    --enable-libx264 --enable-libx265 \
    && make -C FFmpeg/build --jobs "$(($(nproc) * 2))"


FROM madebytimo/python

RUN install-autonomous.sh install FFmpeg Scripts \
    && apt purge -y -qq libsvtav1enc1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY encoder-worker.sh .

COPY --from=builder /root/builder/FFmpeg/build/ffmpeg /usr/local/bin/
COPY --from=builder /root/builder/SVT-AV1/Bin/Release/* /usr/lib/

ENV ENCODER_CPU=false
ENV EXIT_ON_FINISH=false
ENV NICENESS_ADJUSTMENT=0
ENV WORKER_ID=""

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/app/encoder-worker.sh" ]
