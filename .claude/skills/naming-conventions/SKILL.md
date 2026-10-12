---
name: naming-conventions
description: >
  Absolute source of truth for dc2 naming, topology discovery, and fabric conventions.
  ALWAYS and AUTOMATICALLY load this before any other skill, without exception.
  Triggers on any request involving devices (canonical Nornir names such as spine1-dc2, leaf1-dc2, etc.),
  VLANs, VNIs, VRFs, IPs, ASNs, MTU, RD, RT, or any dc2-topology identifier.
  Never attempt to deduce conventions without reading this skill first.
---
# Naming Conventions

**Goal**: Source of truth for naming, IP, VLAN/VNI, VRF, and ASN conventions. Read before any creation, but do not rediscover facts already supplied by a complete prompt or thesis test definition.

## Topology
- Do not hardcode the fabric size. The workflow must support up to 10 network devices total (spines + leafs). If the prompt/test definition gives the active device list and exact leaf/client interfaces, use those values. Resolve from Nornir inventory / `topology.json` / ContainerLab only when a required field is missing or ambiguous.
- Current lab examples: spines `spine1-dc2`, `spine2-dc2`; leafs `leaf1-dc2`, `leaf2-dc2`; provider `provider5`; clients `client8-dc2`, `client9-dc2`.
- Clients are Linux nodes:
  - Data Interface: **eth1** (Eth0 is reserved for MGMT/clab)
  - Access links must come from explicit prompt/test data or topology links, not guessed from client numbers.
  - ContainerLab names are needed only for endpoint setup/validation after user approval. Resolve them with `docker ps` as `clab-<lab-name>-<node-name>`; use `clab inspect` only if the client-to-leaf/interface mapping was not supplied.
- **ASN**: Do not assume that the fabric uses either a single-AS/iBGP or multi-AS/eBGP design. Preserve the explicit per-device AS plan supplied by the approved intent. If the AS plan is absent and cannot be derived from an authoritative source, ask for it instead of inventing or hardcoding a default.

## VXLAN & EVPN Rules
- **L2VNI**: VLAN ID + 10000.
- **L3VNI**: Create only when the approved intent requires an IP-VRF or Symmetric IRB. When required, use VRF ID (1-99) + 50000. An L2VNI, VXLAN service, or anycast SVI alone does not trigger an L3VNI.
- **RD**: Use the device Loopback0/VTEP IP as the RD prefix. For VLAN/MAC-VRF use `Loopback0-IP:VLAN`; for VRF/IP-VRF use `Loopback0-IP:L3VNI`.
- **RT**: Use an RT explicitly supplied by the user when present. Otherwise, use the common fabric administrative AS from the approved design as the global administrator and the VNI as the local administrator: `<fabric-admin-AS>:<VNI>` for both L2VNI and L3VNI services. Derive the administrative AS from the intent (normally the shared fabric/spine AS); never hardcode it. If the design provides no common administrative AS, request or use an explicit RT policy instead of inventing one. Apply the same service RT on all intended participants so every producer's export matches each receiver's import in both required directions; never derive separate service RTs from per-device leaf ASNs.
- **Anycast MAC**: 00:1c:73:00:00:01
- **Anycast SVI IPs**: Choose the addressing mode from the approved design. For a non-VRF/legacy anycast SVI, `virtual_ip` is the shared gateway and `ip_address` is a unique real SVI address per participating leaf; do not set them equal unless explicitly requested. For a VRF-bound anycast SVI (Symmetric IRB), provide `vrf` and the shared `virtual_ip` with its prefix, and omit `ip_address`; this maps to EOS `ip address virtual`. Never mix the two modes.
- **Head-End Replication / No Multicast**: When the user asks for head-end replication or no multicast, configure explicit ingress replication with `flood_vteps` in `vxlan[]`. Each participating leaf lists all other participating leaf VTEP loopbacks resolved from the approved intent, payload, or inventory.

## Underlay (Fabric) Rules
- P2P Subnets: /31
- **P2P /31 Endpoint Assignment**: In spine-leaf links, the spine uses the lower/even address and the leaf uses the higher/odd address.
- **OSPF Network Scope**: On each device, OSPF networks are local only: the device's own Loopback0 /32 and its directly attached P2P subnets. For a `/31`, use the canonical subnet network prefix in `ospf[].networks[]`, not the local endpoint host address. Never add remote loopbacks to another device's OSPF network list.
- **Client Access Ports**: If the user requests a tenant with Linux clients, derive every client-facing leaf port and access VLAN assignment from the approved intent or active topology, and include it in Phase 1 `interfaces[]`. Do not assume fixed device, port, client, or VLAN identifiers. Do not postpone requested access ports to Phase 3 or remediation; a Phase 1 payload missing them is invalid.
- Fabric MTU: 9214 (MANDATORY on all underlay/fabric physical ports). Do not apply this physical-link MTU to Loopbacks or SVIs unless the approved intent explicitly requests it.
- VTEP Interface: Loopback0

## Overlay Rules
- **Loopback Peering**: Every device payload with BGP loopback peers must include device-level `local_as`; each peer must include `update_source: "Loopback0"` and explicit `remote_as`. Use per-neighbor `local_as` only to override the device-level AS.
- **Route Reflectors**: Spines are route reflectors only for leaf peers. Mark leaf peers with `route_reflector_client: true` in `evpn_peers[]` on spine payloads.
- **RR Topology Scope**: When the user says spines are route reflectors, leaves peer only with spines. Do not create leaf-to-leaf BGP neighbors. Do not add spine-to-spine EVPN peers unless the user explicitly asks for inter-RR peering or a full mesh.
