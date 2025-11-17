# Encoder image

This Docker image contains an encoder script and a ffmpeg installation.

It encodes all files in the `input` folder of an SFTP server or the local volume
`/media/encoder/input`. Multiple containers on the same directory are possible. The input folder
contains some special folder which corresponds to arguments for the encode script.

## Installation

1. Pull from [Docker Hub], download the package from [Releases] or build using `builder/build.sh`

## Usage

### Environment variables

-   `CREATE_FOLDERS`
    -   If set to `true` the container creates the predefined input and output folder structure
        before processing, default `true`.
-   `ENCODER_CPU`
    -   Set to `true` to enable cpu encoding.
-   `EXIT_ON_FINISH`
    -   Set to `true` to exit if no more files to encode are present.
-   `MAX_BANDWIDTH`
    -   Limit the upload and download bandwidth, for example `10M` for 10 MB/s.
-   `NICENESS_ADJUSTMENT`
    -   Set a custom niceness adjustment, default `19`.
-   `SCHED_POLICY`
    -   Set the specified scheduling policy, default `idle`.
-   `WORKER_ID`
    -   Id of the worker, default is random.
-   `SERVER_URL`
    -   Server to download from and upload fineshed files to, in the format
        `sftp://user@hostname[:port]`. If empty the local volumes are used.
-   `SERVER_KEY`
    -   SSH key to use for authorization to the server.
-   `SERVER_IDENTITY`
    -   Public key of the server for host key checking.

### Volumes

-   `/media/encoder`
    -   The input and output directory of the files to encode and the encoded files, if no
        `SERVER_URL` is specified.
-   `/media/encoder/input`
    -   The input directory for source files, if no `SERVER_URL` is specified.
-   `/media/encoder/failed`
    -   The output directory for source files of failed encodes, if no `SERVER_URL` is specified.
-   `/media/encoder/output`
    -   The output directory for encoded files, if no `SERVER_URL` is specified.
-   `/media/workdir`
    -   The directory which is used while encoding.

## Development

To build and run the docker container for development execute:

```bash
docker compose --file docker-compose-dev.yaml up --build
```

[Docker Hub]: https://hub.docker.com/r/madebytimo/encoder
[Releases]: https://github.com/mbT-Infrastructure/docker-encoder/releases
