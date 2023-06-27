FROM madebytimo/base

RUN install-autonomous.sh install FFmpeg Scripts \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY encoder-worker.sh .

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/app/encoder-worker.sh" ]
