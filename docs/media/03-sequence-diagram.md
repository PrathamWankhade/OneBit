# 03 — Sequence Diagrams

## 3.1 Attach → Transfer → Delivered (happy path)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UC as AttachFile use case
    participant VAL as MediaValidator
    participant ST as AttachmentStore
    participant PR as MediaProbe
    participant TH as ThumbnailGenerator
    participant DB as TransferRepository
    participant ENG as TransferEngine
    participant AM as AttachmentManager
    participant DTN as DTNRepository

    User->>UC: file path + message/channel context
    UC->>VAL: validate (size, type, ext, checksum, space)
    VAL-->>UC: ValidationResult(ok)
    UC->>ST: stage file into attachments/<category>/
    ST-->>UC: stored path
    UC->>PR: probe (dimensions/duration/pages)
    PR-->>UC: MediaProbeResult
    UC->>TH: generate thumbnail (lazy)
    TH-->>UC: Thumbnail(path)
    UC->>DB: saveAttachment(...)
    DB-->>UC: Attachment(id)
    User->>ENG: startTransfer(attachmentId, peer)
    ENG->>DB: createSession(bitmap of chunks)
    ENG->>AM: announce(session manifest)
    AM->>DTN: store(DtnPacket kind=AM)
    loop each missing chunk
        ENG->>AM: chunk(index, data)
        AM->>DTN: store(DtnPacket kind=AC)
        DTN-->>AM: envelope delivered to peer
        AM->>ENG: onChunkAck(index) [via AK envelope]
        ENG->>DB: markChunkAcked(index)
    end
    AM->>ENG: onAllAcked
    ENG->>DB: completeSession(file hash verified)
    ENG-->>User: TransferSession(completed)
```

## 3.2 Receive side (receiver node)

```mermaid
sequenceDiagram
    autonumber
    participant DTN as DTNRepository
    participant AM as AttachmentManager
    participant ENG as TransferEngine
    participant DB as TransferRepository
    participant ST as AttachmentStore

    DTN-->>AM: envelope kind=AM (announce)
    AM->>ENG: onAnnounce(session, manifest)
    ENG->>DB: createInboundSession(...)
    loop chunk envelopes
        DTN-->>AM: envelope kind=AC
        AM->>ENG: onChunk(session, index, data)
        ENG->>ST: append to temp file
        ENG->>ENG: verify chunk SHA-256
        ENG->>DB: markChunkReceived(index)
        AM->>DTN: store(AK ack for index)
    end
    ENG->>ST: finalize temp → downloads/<name>
    ENG->>ENG: verify whole-file SHA-256
    ENG->>DB: completeInboundSession(...)
    AM->>DTN: store(AD complete)
```

## 3.3 Interrupted transfer + resume

```mermaid
sequenceDiagram
    autonumber
    participant S as Sender TransferEngine
    participant SB as Sender DB
    participant R as Receiver TransferEngine
    participant RB as Receiver DB

    S->>SB: chunks 0..9 acked, 10..19 pending
    Note over S,R: connectivity lost — DTN parks envelopes
    Note over S,R: process restarts (crash)
    S->>SB: restore session from SQLite bitmap
    R->>RB: restore inbound session (temp file + bitmap)
    S->>R: AM announce (resume hint, same session id)
    R->>S: AR request(index=10) .. AR(index=19)
    loop 10..19
        S->>R: AC chunk(index, data)
        R-->>S: AK ack(index)
    end
    S->>SB: complete
    R->>RB: complete + file hash verify
```

## 3.4 Pause / Cancel

```mermaid
sequenceDiagram
    autonumber
    participant U as User
    participant S as TransferEngine
    participant R as Receiver TransferEngine

    U->>S: pauseTransfer(sessionId)
    S->>S: stop scheduler, persist state=paused
    S->>R: AP pause (best effort)
    U->>S: resumeTransfer(sessionId)
    S->>S: scheduler resumes from bitmap
    S->>R: AR request for missing chunks (receiver-driven)
    U->>S: cancelTransfer(sessionId)
    S->>S: state=cancelled, purge temp files
    S->>R: AX cancel
    R->>R: purge temp file, state=cancelled
```

## 3.5 Integrity failure path

```mermaid
sequenceDiagram
    autonumber
    participant S as Sender
    participant R as Receiver
    participant RB as Receiver DB

    R->>R: chunk 4 hash mismatch
    R->>S: AK nack(chunk=4)
    S->>S: mark chunk 4 pending again
    S->>R: AC chunk 4 (retry)
    R->>RB: chunk 4 ok
    Note over R: whole-file hash mismatch at completion
    R->>R: state=failed, keep temp for diagnostics
    R->>S: AX cancel(integrity)
    S->>S: state=failed(integrity) — retry allowed
```