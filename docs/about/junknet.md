# Junkmesh vs Junk Net

Junkmesh is not a replacement for [Junk Net](https://junknet.au) — it's a
research fork run by the same community, asking a different question.

**Junk Net asks:** can we run a friendly, dependable community storage
service on donated hardware? It optimises for operability. A CA and
lighthouses are *features* there: they give the pilot's operators a clear way
to vouch for nodes and help households behind CGNAT connect.

**Junkmesh asks:** how far can we push the same stack toward zero central
infrastructure? It optimises for autonomy and survivability, and accepts
rougher edges in exchange.

## Side by side

| | Junk Net | Junkmesh |
|---|---|---|
| Status | Brisbane pilot | Experiment |
| Overlay network | Nebula (CA + lighthouses) | Yggdrasil (self-organising) |
| Storage | Garage, 3 replicas | Garage, 3 replicas |
| Node onboarding | Operators image and enrol machines | Anyone boots the ISO; clusters admit nodes explicitly |
| Who can shut it down | The pilot operators, in principle | Nobody, in principle |
| Best for | People who want storage that works | People who want to experiment |

## What's shared

The storage layer (Garage), the S3-compatible access model, the licence
(Apache-2.0), the hardware philosophy, and the community. Lessons learned in
Junkmesh — especially around decentralised cluster admission — feed back into
Junk Net's roadmap.
