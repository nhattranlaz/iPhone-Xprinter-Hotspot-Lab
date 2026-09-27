# Xprinter Hotspot LAB — Checkpoint 2026-09-27

## Goal
One phone only: phone provides hotspot -> provision Xprinter onto that hotspot -> obtain printer IP -> TCP/9100 -> ESC/POS print.

## Proven on real iPhone
- Personal Hotspot can host the Xprinter.
- The same iPhone running this LAB can connect to the Xprinter by manually entered IP.
- TCP/9100 PASS.
- ESC/POS test print PASS.
- Therefore direct printing is frozen as a proven path; do not redesign it.

## Provisioning evidence
- Initial ESP-Touch V1 and V2 attempts: no printer acknowledgement.
- Do not infer that Personal Hotspot printing is impossible; printing already passed.
- LAB-3 BSD diagnostic enumerates runtime IPv4 interfaces using getifaddrs.
- On the tested iPhone a runtime candidate exposed 172.20.10.1/28 and calculated broadcast 172.20.10.15; IP_BOUND_IF + bind + sendto returned PASS.
- These addresses and interface names are observations only, NEVER product constants.
- Legacy ESP-Touch V1 assumes x.y.z.255 for broadcast, which can be wrong for non-/24 networks.

## Locked design rule
NEVER hard-code:
- bridge100 / bridge* / en0 / ap1 or any interface name
- 172.20.10.x or any hotspot subnet
- /28 or any netmask
- .255 or any broadcast address

Runtime network resolver must derive:
interface index + IPv4 + netmask + broadcast from the active network stack, then provisioning engines consume that result.

Broadcast formula: IPv4 OR (NOT netmask).

Candidate selection must be capability/runtime based, not brand/device/interface-name based, so the design can survive future iPhone/iOS and other hotspot implementations.

## Current research direction
1. Keep IP -> TCP/9100 -> print frozen.
2. Improve runtime interface resolver and identify the downstream hotspot candidate by measured capabilities.
3. Instrument ESP-Touch socket send path with selected interface/index/source/broadcast, bytes sent, errno, timestamp.
4. Re-test V1 using dynamically resolved routing.
5. Then apply the same resolver/instrumentation to V2.
6. Only after measured results decide whether Raw SmartConfig/protocol analysis is needed.

## UI
Use spacious ScrollView cards and inline navigation title. Avoid translucent/large-title overlap that previously obscured the top half of the screen.
