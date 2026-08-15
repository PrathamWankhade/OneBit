# Binary Format — Phase 6

All integers are unsigned big-endian. There is no optional alignment
padding: bytes are dense in the documented order. The decoder reads
structurally with bounds checks before every read.

## Frame template

```
frame := header(28) nodeSource nodeDestination payloadLength(4)
          payload signatureLength(2) signature crc32(4)

header := [28 bytes]
  byte  0 : transportVersion[4 bits] : reservedNibble[4 bits] = 0
  byte  1 : versionMajor
  byte  2 : versionRevision
  byte  3 : compatibilityFlags
  byte  4 : packetType
  byte  5 : priority[2 bits] : reservedPriority[6 bits] = 0
  byte  6 : flags
  byte  7 : reservedFlags = 0
  byte  8 : ttl
  byte  9 : hopCount
  bytes 10..13 : sequence (u32)
  bytes 14..17 : createdAtEpochSeconds (u32)
  bytes 18..19 : fragmentId (u16)
  bytes 20..21 : fragmentIndex (u16)
  bytes 22..23 : fragmentCount (u16)
  bytes 24..25 : sourceLength (u16)
  bytes 26..27 : destinationLength (u16)
```

`source` is exactly `sourceLength` UTF-8 bytes; `destination` exactly
`destinationLength` UTF-8 bytes (empty ⇒ broadcast). `payload` is exactly
`payloadLength` bytes. `signatureLength == 0` allowed for unsigned frames.

`crc32` = CRC-32/IEEE (init `0xFFFFFFFF`, poly reflected `0xEDB88320`,
final XOR `0xFFFFFFFF`) over all bytes **from index 0 through the last
signature byte** — i.e. everything except the trailing 4 CRC bytes
themselves. The reader recomputes and compares before any semantic check.

## Endianness examples

`sequence = 0x0001_0240` → bytes `00 01 02 40`.
`fragmentCount = 7` → `00 07`.
`createdAtEpochSeconds = 1_650_000_000` → `0x625_` … rendered
big-endian `62 5A 0B 80`.

## Worked example — small text message

Build a packet with:
- transport 1 / major 1 / revision 0
- compat = 0
- type = message (0)
- priority = normal (2)
- flags = ackRequested (0x08)
- ttl 8, hopCount 0
- sequence 42 (`0x0000002A`), createdAt = 1_700_000_000 = `0x6553F100`
- fragmentId 0, index 0, count 1
- source `"AB12CD34"` (8 bytes), destination `"EF56GH78"` (8 bytes)
- payload = ASCII `"hello"` = `0x68 0x69 0x6C 0x6C 0x6F`

Header bytes 0..27:

```
byte  0 : 0x10                     transport=1, reservedNibble=0
byte  1 : 0x01                     major
byte  2 : 0x00                     revision
byte  3 : 0x00                     compat
byte  4 : 0x00                     type message
byte  5 : 0x02                     priority normal
byte  6 : 0x08                     flags ackRequested
byte  7 : 0x00                     reservedFlags
byte  8 : 0x08                     ttl 8
byte  9 : 0x00                     hopCount 0
bytes 10..13 : 0x0000002A          sequence 42
bytes 14..17 : 0x6553F100          createdAt seconds
bytes 18..19 : 0x0000              fragmentId 0
bytes 20..21 : 0x0000              fragmentIndex 0
bytes 22..23 : 0x0001              fragmentCount 1
bytes 24..25 : 0x0008              sourceLength 8
bytes 26..27 : 0x0008              destLength 8
source      : 41 42 31 32 43 44 33 34     "AB12CD34"
destination : 45 46 35 36 47 48 37 38     "EF56GH78"
payloadLen  : 00000005
payload     : 68 69 6C 6C 6F                "hello"
sigLen      : 0x0000
crc32       : <CRC32 over everything above>
```

Frame total = 28 + 16 + 4 + 5 + 2 + 0 + 4 = 59 bytes.

## Fragment rendering

The same template for each fragment of a larger packet, differences only in
`flags` (bit `fragmented` set), `fragmentId` (fixed for the run),
`fragmentIndex` (0..count-1), `fragmentCount` (total) and `payload`
(fragment chunk). A receiver groups frames by
`(source, sequence, fragmentId)` and indexes by `fragmentIndex`.

Example — a 100-byte payload, MTU gives `fragmentSize = 40`:
three frames with `fragmentCount = 3`, indices 0,1,2, payloads of 40, 40,
20 bytes. Frames may arrive interleaved with other packets; reassembly
reorders them.

## Strictness rules of the reader

1. Fixed header reads are bounds-checked; running off the buffer yields
   `Err(PacketValidationFailure.malformed)` — never a partial object.
2. After the payload, exactly `signatureLength` bytes, then 4 CRC bytes
   remain; any other byte count fails rule 3 `headerTrailingByte`.
3. `payloadLength > maxPayloadLength` fails rule 4; decoded frames larger
   than one negotiated MTU without the `fragmented` flag also fail.
4. `crc32` mismatch fails rule 5 before any other semantic step — this is
   deliberate: corrupt bytes never reach reassembly or validation.
5. Encryption-aware frames are validated (CRC, length) but their payload
   is left untouched — never parsed, never unzipped (rule 8).