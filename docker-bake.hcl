variable "BASE_IMAGE_DATE" {
    default = "unknown"
}
variable "IMAGE" {
    default = "unknown"
}
variable "VERSION" {
    default = "v0.0.1"
}

target "default" {
    tags = [
        "${IMAGE}:latest",
        "${IMAGE}:${VERSION}",
        "${IMAGE}:${VERSION}-base-${BASE_IMAGE_DATE}"
    ]
    platforms = [
        "amd64",
        "arm64",
        "arm"
    ]
}
