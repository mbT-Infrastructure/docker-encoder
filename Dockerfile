FROM madebytimo/base

COPY apt-sources.list /etc/apt/sources.list
RUN install-autonomous.sh install ffmpeg Scripts \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY encoder-worker.sh .

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/app/encoder-worker.sh" ]
