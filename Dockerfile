FROM madebytimo/builder AS builder

RUN apt update -qq && apt install -y -qq libass-dev libdav1d-dev libmp3lame-dev libopus-dev \
    libva-dev libvdpau-dev libvorbis-dev libvpx-dev libx264-dev libx265-dev texinfo wget && \
    rm -rf /var/lib/apt/lists/*

RUN export FFMPEG_VERSION="$(curl --silent --location https://ffmpeg.org/download.html \
        | grep --max-count 1 --only-matching 'https://ffmpeg.org/releases/ffmpeg-.*\.tar' \
        | sed 's|^.*ffmpeg-\(.*\)\.tar|\1|')" \
    && curl --silent --location "https://ffmpeg.org/ffmpeg-devel.asc" \
    | gpg --yes --dearmor >> signature-public-keys.gpg \
    && download.sh --name ffmpeg.tar.gz \
        "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz" \
    && download.sh --name signature.asc \
        "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.gz.asc" \
    && gpg --keyring ./signature-public-keys.gpg --no-default-keyring --quiet \
        --verify signature.asc ffmpeg.tar.gz \
    && rm signature-public-keys.gpg signature.asc \
    && compress.sh --decompress ffmpeg.tar.gz \
    && rm ffmpeg.tar.gz \
    && mv ffmpeg-* ffmpeg \
    && download.sh --name svt-av1.tar.gz \
        https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/master/SVT-AV1-master.tar.gz \
    && compress.sh --decompress svt-av1.tar.gz \
    && rm svt-av1.tar.gz \
    && mv SVT-AV1-* svt-av1

RUN cd svt-av1/Build \
    && cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
    && make --jobs "$(nproc)" \
    && make install

RUN mkdir ffmpeg/build \
    && cd ffmpeg/build \
    && ../configure --disable-doc --enable-gpl --enable-libass --enable-libdav1d \
    --enable-libfreetype --enable-libmp3lame --enable-libopus --enable-libsvtav1 \
    --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 \
    && make --jobs "$(($(nproc) * 2))"


FROM madebytimo/base

RUN install-autonomous.sh install FFmpeg MetadataEditors Scripts \
    && apt purge -y -qq libsvtav1* \
    && rm -rf /var/lib/apt/lists/*

COPY files/encoder-worker.sh /usr/local/bin/

COPY --from=builder /root/builder/ffmpeg/build/ffmpeg /usr/local/bin/
COPY --from=builder /root/builder/ffmpeg/build/ffprobe /usr/local/bin/
COPY --from=builder /root/builder/svt-av1/Bin/Release/* /usr/lib/

ENV ENCODER_CPU=false
ENV EXIT_ON_FINISH=false
ENV NICENESS_ADJUSTMENT=19
ENV SCHED_POLICY="other"
ENV WORKER_ID=""

COPY files/entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "encoder-worker.sh" ]
