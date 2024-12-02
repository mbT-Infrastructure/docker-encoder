#!/usr/bin/env bash
set -e

FOLDER_TO_CREATE=(
    /media/encoder/input/no-video
    /media/encoder/output
    /media/workdir
    )

for FOLDER_1 in /no-audio ""; do
    for FOLDER_2 in /compatibility ""; do
        for FOLDER_3 in /low-quality ""; do
            for FOLDER_4 in /crop/{4-3,3-2,5-3,16-9,1.85-1,2-1,2.35-1,2.4-1} ""; do
                for FOLDER_5 in /fps/25 /fps/30 ""; do
                    for FOLDER_6 in /scale/{1280x720,1920x1080,3840x2160} ""; do
                        FOLDER_TO_CREATE+=(
        "/media/encoder/input${FOLDER_1}${FOLDER_2}${FOLDER_3}${FOLDER_4}${FOLDER_5}${FOLDER_6}"
                            )
                    done
                done
            done
        done
    done
done
for FOLDER in "${FOLDER_TO_CREATE[@]}"; do
    echo $FOLDER
    mkdir --parents "$FOLDER"
done

if [[ -z "$WORKER_ID" ]]; then
    export WORKER_ID="$HOSTNAME"
fi

exec "$@"
