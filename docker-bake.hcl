variable "BASE_IMAGE_DATE" {
    default = "unknown"
}
variable "VERSION" {
    default = "v0.0.1"
}

target "default" {
    tags = [
        "madebytimo/encoder:latest",
        "madebytimo/encoder:${VERSION}",
        "madebytimo/encoder:${VERSION}-base-${BASE_IMAGE_DATE}"
    ]
    platforms = [
        "amd64",
        "arm64",
        "arm",
    ]
}