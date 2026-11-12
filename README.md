# Prime-OS

A project for building an operating system. The current prototype is a Faravahar-themed OS image downloader with a progress animation synchronized to actual download bytes.

## Download UI

Install the dependencies (`numpy`, `matplotlib`, `pillow`, and `contourpy`), then run:

```bash
python loader.py faravahar.png --download https://example.com/system.iso --output system.iso
```

The progress display requires the download server to provide a valid `Content-Length` header. The image is saved to the requested output path only after the full download is verified.
