#!/usr/bin/env bash
set -e

INPUT_DIR="/media/encoder/input"
FAILED_DIR="/media/encoder/failed"
OUTPUT_DIR="/media/encoder/output"
WORKDIR="/media/workdir"

if [[ "$ENCODER_CPU" != true ]]; then
    ENCODER_CPU=false
fi
if [[ "$ENCODER_LOW_QUALITY" != true ]]; then
    ENCODER_LOW_QUALITY=false
fi
WORKER_INPUT_DIR="${INPUT_DIR}/.working/$WORKER_ID"
WORKER_OUTPUT_DIR="${OUTPUT_DIR}/.working/$WORKER_ID"

echo "Start encoder worker \"${WORKER_ID}\" (cpu: ${ENCODER_CPU})."
cd "$WORKDIR"

cleanup () {
    echo "Do cleanup."
    for FILE in "$WORKER_INPUT_DIR/"*; do
        if [[ -f "$FILE"  ]]; then
            mkdir --parents "$FAILED_DIR"
            mv "$FILE" "$FAILED_DIR"
        fi
    done
    rm --force --recursive "$WORKER_INPUT_DIR" "$WORKER_OUTPUT_DIR"
}

trap cleanup SIGINT SIGTERM

if [[ -d "$WORKER_INPUT_DIR" ]]; then
    echo "Worker directory already exists."
    cleanup
fi

WORKER_FILE=""
while true; do
    WORKER_FILE="$(find "$INPUT_DIR" -type f -print -or \
        -path "${INPUT_DIR}/.working" -prune | tail --lines 1)"
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
        if [[ "$WORKER_FILE_RELATIVE_FOLDER" == audio?(/*) ]]; then
            ARGUMENTS_FOR_ENCODER+=(--audio)
            WORKER_FILE_RELATIVE_FOLDER="${WORKER_FILE_RELATIVE_FOLDER#audio}"
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
        mkdir --parents "$WORKER_INPUT_DIR"
        mv "$WORKER_FILE" "${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME}"
        cp "${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME}" "${WORKDIR}/${WORKER_FILE_BASENAME}"
        nice --adjustment "$NICENESS_ADJUSTMENT" \
            encode.sh --replace "${ARGUMENTS_FOR_ENCODER[@]}" "${WORKDIR}/${WORKER_FILE_BASENAME}"
        mkdir --parents "$WORKER_OUTPUT_DIR"
        mv "${WORKDIR}/${WORKER_FILE_BASENAME%.*}."* "$WORKER_OUTPUT_DIR"
        mkdir --parents "${OUTPUT_DIR}/${WORKER_FILE_RELATIVE_FOLDER}"
        mv "${WORKER_OUTPUT_DIR}/${WORKER_FILE_BASENAME%.*}."* \
            "${OUTPUT_DIR}/${WORKER_FILE_RELATIVE_FOLDER}"
        rm "${WORKER_INPUT_DIR}/${WORKER_FILE_BASENAME%.*}."*
        cleanup
        echo "Finished encode of \"${WORKER_FILE}\""
    fi
done
