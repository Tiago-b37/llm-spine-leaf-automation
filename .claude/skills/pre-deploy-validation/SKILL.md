---
name: pre-deploy-validation
description: >
  Intent linting. Triggers immediately after intent-parser or when the user
  asks to validate resources BEFORE configuring them (e.g., "check if vlan is free",
  "check for conflicts"). Blocks the application of overlapping configs.
---
# Pre-Deploy Validation

**Goal**: Lint the intent before generating config, preventing avoidable breakage.

## Rules

1. **Zero Pre-Checks (MANDATORY)**: Do NOT run `get_fabric_health`, `list_all_hosts`, `get_interfaces_ip`, `get_config`, LLDP, or `show running-config` prior to Phase 1 when the user already named the target devices and P2P links. Assume a healthy clean slate to minimize latency.
   - If the user request includes Linux tenant clients, lint the Phase 1 payload before calling tools: every client-facing leaf port must be present in `interfaces[]` with `switchport_mode: "access"` and the requested `access_vlan`.
   - A Phase 1 payload that omits client access ports is invalid. Fix the Phase 1 payload before `dry_run`; do not defer the ports to Phase 3.
   - Lint every eBGP underlay payload: directly connected spine-leaf peers must use the peer P2P IP and explicit `remote_as`; every underlay device must advertise Loopback0 using `bgp_networks[]`.
   - Lint every loopback BGP peer: the device payload must include `local_as`; `bgp_neighbors[]` must include `update_source: "Loopback0"` and explicit `remote_as`, using per-neighbor `local_as` only for an intentional override. Loopback-based eBGP must include `ebgp_multihop`.
   - Lint OSPF only when the user explicitly selected OSPF: `ospf[].networks[]` must contain only local Loopback0 and directly attached P2P subnets for that device.
   - Lint spine route-reflector payloads only when the user explicitly requested an iBGP RR design: leaf `evpn_peers[]` on spines must include `route_reflector_client: true`, and leaves should peer with spines only.
   - Lint every VXLAN payload: if the user requested head-end replication/no multicast, `vxlan[]` entries must include explicit `flood_vteps` listing the remote participating leaf VTEP loopbacks.
   - Lint every L2 VXLAN payload: each `vxlan[]` entry must include both `vni` and the matching `vlan_id` present in `vlans[]`.
   - **Payload Contract Check**: Before dry-run, compare the complete generated payload with the approved structured intent and the selected tool schema. Reject both capabilities that are neither explicitly requested nor strict dependencies of the selected design, and missing required or conditionally required fields or cross-object dependencies; never change the design class through inference.
   - Preserve explicit intent attributes: verify that requested operational values such as interface MTU remain present in every applicable deployment payload. Apply a fabric/underlay MTU only to physical fabric ports; do not copy it to Loopbacks or SVIs unless explicitly requested.
   - Include device-level `local_as` in every payload containing BGP-dependent objects: `bgp_neighbors`, `bgp_networks`, `evpn_peers`, `evpn_rd_rt`, or a VRF with RD/RT. Do not assume that a later phase inherits the AS from an earlier call.
   - Lint EVPN RT compatibility by service: every producer's export RT must match an import RT on each intended receiver; validate both directions for bidirectional services.
2. **Day-N Prepared Baseline**: For Day-N changes on a prepared spine-leaf fabric, trust a validated baseline and the prompt/test definition as the starting state. Prefer the dry-run as the preflight check. Use compact live-state reads only when a required input is missing/ambiguous or a gate fails.
3. **Evidence-Driven Discovery**: For any Day-N change, each read command must prove a specific pre-change invariant required by the next payload. Stop discovery as soon as those invariants are proven. Prefer no pre-change reads when the payload can be generated from the prompt/test definition. If one invariant must be checked across leaves, prefer one summary tool or one targeted multi-device read over repeated per-device `send_command` calls. Do not inspect running-config, full BGP config, broad interface IP dumps, client container state, or unrelated device roles unless compact checks cannot prove the invariant or have failed.

## Safety Handoff

- **P3 STOP BOUNDARY**: After the Phase 3 `check_dataplane_summary` gate passes, stop immediately and ask for endpoint verification approval before resolving/configuring Linux clients or running pings. The approval question must be the final action in that turn.
