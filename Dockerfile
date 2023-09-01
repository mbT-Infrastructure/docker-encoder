FROM madebytimo/python

RUN install-autonomous.sh install FFmpeg Scripts \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY encoder-worker.sh .

ENV ENCODER_CPU=false
ENV EXIT_ON_FINISH=false
ENV NICENESS_ADJUSTMENT=0
ENV WORKER_ID=""

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "/app/encoder-worker.sh" ]
