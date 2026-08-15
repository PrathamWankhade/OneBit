# 14 — Future Streaming

## 14.1 Streaming playback

Phase 9 transports whole files. Streaming (play-before-download) is
prepared by design, not implemented:

- Chunks are indexed and offset-addressed; a future `StreamingSession` can
  request `AR` from any index onward.
- Envelope kinds are versioned (`v` field) and additive — new kinds like
  `AS` (stream start) or `AB` (byte range) do not break v1 peers.
- The storage layer already appends at absolute offsets, so a partially
  received file is a valid prefix for a media player.
- Voice recordings carry duration + waveform, which is exactly what a
  streaming UX needs; the recorder/player seams are interfaces ready for a
  native streaming implementation.

## 14.2 Encrypted media (at rest + in transit)

- Wire envelopes are plaintext v1, exactly like messaging envelopes. The
  future crypto layer seals envelope payloads at the *packet protocol*
  boundary (per `01-architecture.md` the media layer never sees transport).
  Media envelope fields are data, not secrets; no media redesign needed.
- At rest, payload columns are typed/planned for ciphertext, paths point
  to future `<attachmentId>.enc` files, and the store keeps an
  `encryptReady` layout (category folders never couple to plaintext).
- "Encrypted Storage Ready" is satisfied structurally: the media engine
  treats bytes as opaque, so sealing/unsealing can be interposed in the
  stage/read pipelines.

## 14.3 Native acceleration (C++ core)

- Image/video compression: the `Compressor` interface already models
  `nativeImage` / `nativeVideo` methods with quality profiles; the C++ core
  (Phase 3+ FFI) plugs in without changing the engine.
- Raster thumbnails: `ThumbnailGenerator` will gain a `native` generator;
  the pure-Dart generator stays as the offline fallback.
- Hashing: `cryptography` package is used today; native SHA-256 can replace
  it at the `AttachmentHasher` seam (single call site).

## 14.4 Larger chunks / binary wire

- v1 uses JSON + base64 inside DTN envelopes (established pattern).
- A binary envelope (`b'\x4D\x41'` magic + varints) can later double
  throughput; the codec switch is internal to `AttachmentWireCodec`, and the
  `kind` discriminator stays unchanged.

## 14.5 Group / broadcast attachments

- v1 transfers are 1:1 (peer-addressed sessions). Group delivery reuses the
  announce/chunk/ack protocol per destination; the model already carries
  `peerNodeId`, and a `channelId` on `Attachment` allows fan-out bookkeeping
  later.