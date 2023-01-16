# Encoder image

This Docker image contains a the encoder script and a ffmpeg installation.

It encodes all files in `/media/encoder/input`. Multiple containers on the same directory are possible.


## Environment variables

- `ENCODER_CPU`
    - Set to `true` to enable cpu encoding.
- `ENCODER_LOW_QUALITY`
    - Set to `true` to enable low-quality encoding for smaller files.
- `EXIT_ON_FINISH`
    - Set to `true` to enable exit on finish which means exit if no more files to encode are present.
- `WORKER_ID`
    - Id of the worker, default iis random.


## Volumes

- `/media/encoder`
    - The input and output directory of the files to encode and the encoded files.
- `/media/encoder/input`
    - The input directory with unencoded files.
- `/media/encoder/output`
    - The output directory with encoded files.
- `/media/workdir`
    - The directory which is used while encoding.


## Development

To build the image locally run:
```bash
./docker-build.sh
```