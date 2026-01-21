#!/usr/bin/env bash
set -e -o pipefail

FOLDER_TO_CREATE=(
    input/no-video
    output
    )

for FOLDER_1 in /no-audio ""; do
    for FOLDER_2 in /compatibility ""; do
        for FOLDER_3 in /low-quality ""; do
            for FOLDER_4 in /crop/{4-3,3-2,14-9,5-3,16-9,1.85-1,2-1,2.35-1,2.39-1,2.4-1} ""; do
                for FOLDER_5 in /fps/{25,30,60} ""; do
                    for FOLDER_6 in /scale/{1280x720,1920x1080,3840x2160} ""; do
                        for FOLDER_7 in /trim/{00:00:00-00:01:00,00:00:30-99:00:00} ""; do
                            FOLDER_TO_CREATE+=(
            "input${FOLDER_1}${FOLDER_2}${FOLDER_3}${FOLDER_4}${FOLDER_5}${FOLDER_6}${FOLDER_7}"
                                )
                        done
                    done
                done
            done
        done
    done
done

echo "Creating folders." >&2

for FOLDER in "${FOLDER_TO_CREATE[@]}"; do
    if [[ -z "$SERVER_URL" ]]; then
        mkdir --parents "/media/encoder/$FOLDER"
    else
        rclone mkdir ":sftp:$FOLDER"
    fi
done
