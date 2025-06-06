# Encoder image

This Docker image contains a the encoder script and a ffmpeg installation.

It encodes all files in `/media/encoder/input`. Multiple containers on the same directory are possible.
The input folder contains some special folder which correspont to arguments for the encode script.


## Environment variables

- `ENCODER_CPU`
    - Set to `true` to enable cpu encoding.
- `EXIT_ON_FINISH`
    - Set to `true` to exit if no more files to encode are present.
- `NICENESS_ADJUSTMENT`
    - Set a custom niceness adjustment, default `19`.
- `SCHED_POLICY`
    - Set the specified scheduling policy, default `other`.
- `WORKER_ID`
    - Id of the worker, default is random.


## Volumes

- `/media/encoder`
    - The input and output directory of the files to encode and the encoded files.
- `/media/encoder/input`
    - The input directory for source files.
- `/media/encoder/failed`
    - The output directory for source files of failed encodes.
- `/media/encoder/output`
    - The output directory for encoded files.
- `/media/workdir`
    - The directory which is used while encoding.


## Development

To build the image locally run:
```bash
./docker-build.sh
```
