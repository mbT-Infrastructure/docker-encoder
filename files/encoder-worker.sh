#!/usr/bin/env bash
set -e -o pipefail

LOCAL_BASE_DIR="/media/encoder"
INPUT_DIR="input"
FAILED_DIR="failed"
OUTPUT_DIR="output"
WORKDIR="/media/workdir"

if [[ "$ENCODER_CPU" != true ]]; then
    ENCODER_CPU=false
fi
if [[ "$ENCODER_LOW_QUALITY" != true ]]; then
    ENCODER_LOW_QUALITY=false
fi
WORKER_INPUT_DIR="${INPUT_DIR}/.working/$WORKER_ID"
WORKER_OUTPUT_DIR="${OUTPUT_DIR}/.working/$WORKER_ID"

if [[ "$CREATE_FOLDERS" == true ]]; then
    create-folders.sh
fi

echo "Start encoder worker \"${WORKER_ID}\" (cpu: ${ENCODER_CPU})."
cd "$WORKDIR"

cleanup () {
    echo "Do cleanup."
    rm --force --recursive "${WORKDIR:?}"/*
    if [[ -z "$SERVER_URL" ]]; then
        for FILE in "${LOCAL_BASE_DIR}/$WORKER_INPUT_DIR/"*; do
            if [[ -f "$FILE"  ]]; then
                mkdir --parents "${LOCAL_BASE_DIR}/$FAILED_DIR"
                mv "$FILE" "${LOCAL_BASE_DIR}/$FAILED_DIR"
            fi
        done
        rm --force --recursive "${LOCAL_BASE_DIR:?}/${WORKER_INPUT_DIR:?}" \
            "${LOCAL_BASE_DIR:?}/${WORKER_OUTPUT_DIR:?}"
    else
        rclone --config "" moveto ":sftp:${WORKER_INPUT_DIR}/" \
            ":sftp:$FAILED_DIR" > /dev/null 2>&1 || true
        rclone --config "" purge ":sftp:$WORKER_INPUT_DIR" > /dev/null 2>&1 || true
        rclone --config "" purge ":sftp:$WORKER_OUTPUT_DIR" > /dev/null 2>&1 || true
    fi
}

trap cleanup SIGINT SIGTERM

if [[ -z "$SERVER_URL" ]] && [[ -d "${LOCAL_BASE_DIR:?}/$WORKER_INPUT_DIR" ]] \
    || rclone --config "" lsd ":sftp:$WORKER_INPUT_DIR" > /dev/null 2>&1; then
    echo "Worker directory already exists."
    cleanup
fi

WORKER_FILE=""
while true; do
    if [[ -z "$SERVER_URL" ]]; then
        WORKER_FILE="$(find "${LOCAL_BASE_DIR}/$INPUT_DIR" -type f -print -or \
            -path "${LOCAL_BASE_DIR}/${INPUT_DIR}/.working" -prune | shuf --head-count 1)"
        WORKER_FILE="${WORKER_FILE#"${LOCAL_BASE_DIR}/"}"
    else
        WORKER_FILE="$(rclone --config "" lsf --exclude '.working/' --files-only \
            --recursive ":sftp:$INPUT_DIR" | shuf --head-count 1 | sed "s|^|${INPUT_DIR}/|")"
    fi
    if [[ -z "$WORKER_FILE" ]]; then
        echo "No worker file found."
        if [[ "$EXIT_ON_FINISH" == true ]]; then
            echo "Exit on finish is enabled."
            exit 0
        else
            echo "Wait 10min."
            sleep 600
        fi
    else
        echo "Prepare encode of \"${WORKER_FILE}\"."
        ARGUMENTS_FOR_ENCODER=()
        if [[ "$ENCODER_CPU" == true ]]; then
            ARGUMENTS_FOR_ENCODER+=(--cpu)
        fi
        WORKER_FILE_BASENAME="$(basename "${WORKER_FILE}")"
        WORKER_FILE_RELATIVE_FOLDER="$(dirname "${WORKER_FILE#"${INPUT_DIR}/"}")"
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == no-audio?(/*) ]]; then
            ARGUMENTS_FOR_ENCODER+=(--no-audio)
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#no-audio}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == no-video?(/*) ]]; then
            ARGUMENTS_FOR_ENCODER+=(--no-video)
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#no-video}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == compatibility?(/*) ]]; then
            ARGUMENTS_FOR_ENCODER+=(--compatibility)
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#compatibility}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == low-quality?(/*) ]]; then
            ARGUMENTS_FOR_ENCODER+=(--low-quality)
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#low-quality}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == crop?(/*) ]]; then
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#crop}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
            CROP_PARAMETER="${WORKER_FILE_RELATIVE_FOLDER%%/*}"
            ARGUMENTS_FOR_ENCODER+=(--crop "$CROP_PARAMETER")
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#"$CROP_PARAMETER"}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == fps?(/*) ]]; then
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#fps}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
            FPS_PARAMETER="${WORKER_FILE_RELATIVE_FOLDER%%/*}"
            ARGUMENTS_FOR_ENCODER+=(--fps "$FPS_PARAMETER")
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#"$FPS_PARAMETER"}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == scale?(/*) ]]; then
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#scale}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
            SCALE_PARAMETER="${WORKER_FILE_RELATIVE_FOLDER%%/*}"
            ARGUMENTS_FOR_ENCODER+=(--scale "$SCALE_PARAMETER")
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#"$SCALE_PARAMETER"}"
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#/}"
        fi

        if [[ -z "$SERVER_URL" ]]; then
            mkdir --parents "${LOCAL_BASE_DIR}/$WORKER_INPUT_DIR"
            mv "${LOCAL_BASE_DIR}/$WORKER_FILE" \
                "${LOCAL_BASE_DIR}/${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME}"
            cp "${LOCAL_BASE_DIR}/${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME}" \
                "${WORKDIR}/${WORKER_FILE_BASENAME}"
        else
            rclone --config "" mkdir ":sftp:$WORKER_INPUT_DIR"
            rclone --config "" moveto ":sftp:$WORKER_FILE" \
                ":sftp:${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME}"
            rclone --config "" copyto \
                ":sftp:${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME}" \
                "${WORKDIR}/${WORKER_FILE_BASENAME}"
        fi
        low-priority.sh \
            encode.sh --replace "${ARGUMENTS_FOR_ENCODER[@]}" "${WORKDIR}/${WORKER_FILE_BASENAME}"
        OUTPUT_FILE_BASENAME="$(basename "${WORKDIR}/${WORKER_FILE_BASENAME%.*}."*)"
        if [[ -z "$SERVER_URL" ]]; then
            mkdir --parents "${LOCAL_BASE_DIR}/$WORKER_OUTPUT_DIR"
            mv "${WORKDIR}/${OUTPUT_FILE_BASENAME}" "${LOCAL_BASE_DIR}/$WORKER_OUTPUT_DIR"
            mkdir --parents "${LOCAL_BASE_DIR}/${OUTPUT_DIR}/${WORKER_FILE_RELATIVE_FOLDER}"
            mv "${LOCAL_BASE_DIR}/${WORKER_OUTPUT_DIR}/${OUTPUT_FILE_BASENAME}" \
                "${LOCAL_BASE_DIR}/${OUTPUT_DIR}/${WORKER_FILE_RELATIVE_FOLDER}"
            rm "${LOCAL_BASE_DIR}/${WORKER_INPUT_DIR}/${OUTPUT_FILE_BASENAME}"
        else
            rclone --config "" mkdir ":sftp:$WORKER_OUTPUT_DIR"
            rclone --config "" moveto "${WORKDIR}/${OUTPUT_FILE_BASENAME}" \
                ":sftp:${WORKER_OUTPUT_DIR}/${OUTPUT_FILE_BASENAME}"
            rclone --config "" mkdir ":sftp:${OUTPUT_DIR}/$WORKER_FILE_RELATIVE_FOLDER"
            rclone --config "" moveto \
                ":sftp:${WORKER_OUTPUT_DIR}/${OUTPUT_FILE_BASENAME}" \
                ":sftp:${OUTPUT_DIR}/${WORKER_FILE_RELATIVE_FOLDER}/${OUTPUT_FILE_BASENAME}"
            rclone --config "" delete \
                ":sftp:${WORKER_INPUT_DIR}/${OUTPUT_FILE_BASENAME}"
        fi
        cleanup
        echo "Finished encode of \"${WORKER_FILE}\""
    fi
done
