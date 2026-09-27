# iPhone Xprinter Hotspot Lab

Independent iOS research app. This repository does not depend on WWT2.

## LAB-1 goal
Prove that an iPhone hosting Personal Hotspot can open a TCP connection to an Xprinter joined to that hotspot and send raw ESC/POS data on port 9100.

## Test
1. Enable Personal Hotspot on iPhone.
2. Configure Xprinter to join that hotspot.
3. Determine the printer IPv4 address.
4. Enter it in the app.
5. Tap Test TCP, then Print ESC/POS.

No multicast or automatic discovery is used in LAB-1.
