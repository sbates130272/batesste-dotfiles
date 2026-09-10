Provide information about the nodes in the storage partition of the Alola Slurm cluster.

## Storage Partition Nodes

| Server / Hostname | PO/Q | Serial | BMC IP / Code | Notes |
| --- | --- | --- | --- | --- |
| ctr-smc-mi300x-cx67-5 | 8601414942 | S911776X6507314 | 10.7.32.204 / CQUHSRHECQ | 2 x Pollara FE, 8 x CX7 BE |
| ctr-smc-mi300x-cx67-15 | 8601414947 | S911776X6507312 | 10.7.32.127 / TWJFYFVREY | 2 x BRCM FE, 8 x CX7 BE |
| ctr-smc-mi300x-cx67-25 | 8601414974 | S911776X6507809 | 10.7.32.211 / CTXOUJCUXW | 2 x Bluefield FE, 8 x CX7 BE |
| ctr-smc-mi300x-cx68-25 | 8601414970 | S911776X6507313 | 10.7.38.23 / BZRBUHNKHK | 2 x CX7 FE, 8 x CX7 BE |
| ctr-smc-strg-cx68-3 | | S892945X6416014 | 10.7.32.214 / MZVFPNEWZI | 2 x BRCM FE |
| ctr-smc-strg-cx68-5 | | S892945X6416013 | 10.7.33.10 / EYNXOQCRLY | 2 x BRCM FE |

## Switches

| Switch / Hostname | BMC IP | Credentials | Role |
| --- | --- | --- | --- |
| ctr-fsswitch-cx69-25 | 10.7.200.227 | admin / AH | FE |
| ctr-fsswitch-cx68-34 | 10.7.38.210 | admin / AH | BE |

## Notes
- All nodes use Alola credentials unless otherwise stated.
- FE = Front End network interface; BE = Back End network interface.
- `ctr-smc-strg-*` nodes are dedicated storage servers (no GPU).
- `ctr-smc-mi300x-*` nodes are MI300X GPU compute nodes also serving the storage partition.
