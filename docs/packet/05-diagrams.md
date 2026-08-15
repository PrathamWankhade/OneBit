# Packet Diagrams — Phase 6

## Component diagram

```
┌────────────────────────────────────────────────────────────────────┐
│ presentation/  packet_providers · packet_controllers               │
│                packet_dev_screen (/packet-debug)                    │
└───────────────┬────────────────────────────────────────────────────┘
                │ watch / read (contract)
┌───────────────▼────────────────────────────────────────────────────┐
│ domain/  PacketRepository (contract)  · Packet · PacketHeader ·    │
│          PacketPayload · PacketType · PacketPriority · PacketFlag · │
│          PacketVersion · PacketId · fragment/reassembly models      │
└───────────────┬────────────────────────────────────────────────────┘
                │ implement
┌───────────────▼────────────────────────────────────────────────────┐
│ data/  PacketRepositoryImpl ────► PacketEngine                      │
│         PacketFactory ─► PacketSerializer ─► PacketFragmenter       │
│         PacketValidator ─► PacketChecksum ─► PacketCompressor       │
│         PacketReassembler ─► PacketVersionManager                   │
│         PacketAuthenticator (interface)                             │
└───────────────┬────────────────────────────────────────────────────┘
                │ send(destination, serializedPacket)
┌───────────────▼────────────────────────────────────────────────────┐
│ mesh/  MeshRepository.send · DeliverUp events                       │
└────────────────────────────────────────────────────────────────────┘
        pure Dart, no Flutter imports below this line
```

## Sequence — send path (factory → fragment → mesh)

```
App             PacketFactory       PacketFragmenter      PacketSerializer
 │ create(utf8)      │                    │                     │
 │──────────────────►│  build header      │                     │
 │                  │  compress?         │                     │
 │                  │  sign?             │                     │
 │                  │  serialize         │                     │
 │                  │  size > MTU ?      │                     │
 │                  │───────────────────►│  split payload      │
 │                  │                    │  per fragment: header│
 │                  │                    │  + chunk            │
 │                  │                    │  serialize each     │
 │                  └────────────────────┴───► frames          │
 │                                                             │
 │  MeshRepository.send(dst, frameBytes) per fragment          │
```

## Sequence — receive path (deliver-up → validate → reassemble → deliver)

```
Mesh DeliverUp            PacketValidator         PacketReassembler     App
 │ payload bytes              │                        │                │
 │───────────────────────────►│  header read           │                │
 │                            │  crc check             │                │
 │                            │  semantic rules 1..14  │                │
 │  fragmented?               │                        │                │
 │────────────────────────────┼───────────────────────►│  key           │
 │                            │                        │  (source,seq,  │
 │                            │                        │   fragmentId)  │
 │                            │                        │  buffer index  │
 │                            │                        │  complete?     │
 │                            │   deliver(packet)      │                │
 │◄───────────────────────────┼────────────────────────│   emitPacket   │
 │  higher layer consumes     │                        │                │
```

## State diagram — a reassembly session

```
      first fragment arrives
   ┌───────────────────────────────┐
   │           collecting          │
   │  buffered = {received indices}│
   └───────────────┬───────────────┘
                   │
        all indices present
                   ▼
   ┌───────────────────────────┐
   │      complete             │  emit one ordered packet
   │  slots freed, session      │  and remove session
   └───────────────────────────┘
        timeout (30 s)
   ┌───────────────────────────┐
   │      expired              │  drop partial set,
   │                           │  free slot, log
   └───────────────────────────┘
```

States are per `(source, sequence, fragmentId)`; the engine caps live
sessions at `maxConcurrentAssemblies` (oldest session evicted first, only
after timeout).

## Timing diagram — fragment interleaving

```
A sends packet P (3 fragments), then packet Q (2 fragments) before P
fully arrives at B. Reassembly keys keep them apart:

A ──► P0(fid 7,i0) B
A ──► P1(fid 7,i1) B
A ──► Q0(fid 9,i0) B
A ──► P2(fid 7,i2) B   ← P completes first, delivered
A ──► Q1(fid 9,i1) B   ← Q completes second, delivered

No fragment of P is ever merged into Q because (source, seq, fid) differ.
```