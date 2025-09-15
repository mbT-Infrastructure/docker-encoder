FROM madebytimo/builder AS builder

RUN apt update -qq && apt install -y -qq libass-dev libdav1d-dev libmp3lame-dev libopus-dev \
    libva-dev libvdpau-dev libvorbis-dev libvpx-dev libx264-dev libx265-dev nasm texinfo && \
    rm -rf /var/lib/apt/lists/*

RUN FFMPEG_VERSION="$(curl --silent --location https://ffmpeg.org/download.html \
        | grep --max-count 1 --only-matching 'https://ffmpeg.org/releases/ffmpeg-.*\.tar' \
        | sed 's|^.*ffmpeg-\(.*\)\.tar|\1|')" \
    SVTAV1_VERSION="$(download.sh --silent --output - \
        https://gitlab.com/api/v4/projects/AOMediaCodec%2FSVT-AV1/releases \
        | sed --null-data --silent 's|^[^{]*{[^{]*"tag_name":[^"]*"\([^"]*\)".*$|\1|p')" \
    && download.sh --silent --output - "https://ffmpeg.org/ffmpeg-devel.asc" \
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
        "https://gitlab.com/AOMediaCodec/SVT-AV1/-/archive/${SVTAV1_VERSION}/\
SVT-AV1-${SVTAV1_VERSION}.tar.gz" \
    && compress.sh --decompress svt-av1.tar.gz \
    && rm svt-av1.tar.gz \
    && mv SVT-AV1-* svt-av1 \
    && mkdir --parents output/{bin,lib}

RUN cd svt-av1/Build \
    && cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release \
    && make --jobs "$(nproc)" \
    && make install --jobs "$(nproc)" \
    && mv /root/builder/svt-av1/Bin/Release/lib* /root/builder/output/lib/

RUN mkdir ffmpeg/build \
    && cd ffmpeg/build \
    && ../configure --bindir=/root/builder/output/bin --libdir=/root/builder/output/lib \
        --shlibdir=/root/builder/output/lib --pkgconfigdir=lib/pkgconfig \
        --disable-doc --disable-ffplay --enable-gpl --enable-libass --enable-libdav1d \
        --enable-libfreetype --enable-libmp3lame --enable-libopus --enable-libsvtav1 \
        --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 \
        --enable-rpath --enable-shared \
    && make --jobs "$(($(nproc) * 2))" \
    && make install --jobs "$(nproc)" \
    && for COMMAND in /root/builder/output/bin/*; do \
        ldd "$COMMAND" \
            | sed --silent 's|^[^/]*\(/lib/\S*\)\s.*$|\1|p' \
            | while read -r LIBRARY; do \
                cp --no-clobber "$LIBRARY" /root/builder/output/lib; \
            done \
    done

FROM madebytimo/base

RUN install-autonomous.sh install MetadataEditors Scripts \
    && apt update -qq && apt install -y -qq rclone \
    && rm -rf /var/lib/apt/lists/* \
    \
    && mkdir /media/workdir /media/encoder

COPY --from=builder /root/builder/output/bin/* /usr/local/bin/
COPY --from=builder /root/builder/output/lib/* /usr/lib/

COPY files/create-folders.sh files/encoder-worker.sh files/entrypoint.sh /usr/local/bin/

ENV CREATE_FOLDERS=true
ENV ENCODER_CPU=false
ENV EXIT_ON_FINISH=false
ENV NICENESS_ADJUSTMENT=19
ENV SCHED_POLICY="idle"
ENV SERVER_IDENTITY=""
ENV SERVER_KEY=""
ENV SERVER_URL=""
ENV WORKER_ID=""

ENTRYPOINT [ "entrypoint.sh" ]
CMD [ "encoder-worker.sh" ]

LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.source="https://github.com/mbT-Infrastructure/docker-encoder"
