---
name: evpn-tenant-manager
description: >
  Configures and migrates EVPN/VXLAN tenant services on Arista cEOS.
  Use whenever a request creates, changes, or removes tenant dataplane objects,
  including VLAN-to-VNI mappings, VXLAN, SVI/anycast gateways, EVPN RD/RT,
  tenant VRFs/L3VNIs, or tenant client access, in Zero-to-Hero Phase 3 or Day-N.
  Uses Nornir MCP configuration tools with dry-run safety.
---
# EVPN Tenant Manager

**Goal**: Provision L2/L3 tenants on Arista cEOS using Nornir MCP tools.

## Rules
1. ALWAYS read `naming-conventions` first.
2. ALWAYS use `mode="dry_run"` first for `configure_*` tools. For Zero-to-Hero phases, immediately apply the returned `dry_run_id` with `apply_fabric_dry_run` unless the dry-run fails; do not pause for human confirmation inside a successful phase.
3. **CRITICAL BULK RULE**: For multi-device tenant deployments, configure every tenant object that belongs to the same approved phase in one `configure_fabric_bulk` call for the whole participating fabric. In Zero-to-Hero, client access ports belong to Phase 1 and must not be duplicated in the dataplane payload; in a Day-N tenant change without a Phase 1, an explicitly requested access-port change may be included in the atomic tenant transaction. Use `configure_device_bulk` only for explicitly single-device operations. Use `configure_vrf` only for standalone single-device VRF work or when the user explicitly asks for that tool. Do NOT split objects that target the same phase into separate calls.
4. **Anycast SVI Rule**: Choose the SVI addressing mode from the approved design. For a non-VRF/legacy anycast SVI, provide BOTH `ip_address` (the unique real leaf SVI IP) and `virtual_ip` (the shared gateway), and do not set them equal unless explicitly requested. For a VRF-bound anycast SVI (Symmetric IRB), provide `vrf` and `virtual_ip` with its prefix, and omit `ip_address`; the backend renders EOS `ip address virtual`. Never mix the two modes.
5. **Head-End Replication Rule:** When the user asks for "head-end replication" or "no multicast", implement it with explicit `flood_vteps` in the VXLAN config. Each participating leaf must list all other participating leaf VTEP loopbacks resolved from the approved intent, payload, or inventory.
6. **Overlay Peering Rule:** When tenant deployment depends on an EVPN overlay, rely on the prepared baseline or previous phase gate if it already validated the overlay. If the overlay has not been validated in the current workflow, use `check_evpn_summary` on the intended VTEP leaves. Do not inspect raw BGP/EVPN configuration just to reconfirm a valid baseline. The thesis default is direct leaf-to-leaf eBGP EVPN between VTEP leaves; spines provide underlay reachability only. Use spine route reflectors and `route_reflector_client` only when the user explicitly requests an iBGP RR design.
7. **Tenant Migration Cleanup:** When the approved migration removes an old VLAN/VNI mapping, use `delete_vxlan` with the old `vlan_id`. Set `cleanup_vlan=true` and provide the device `local_as` when stale tenant state must be removed. Follow the tool's dry-run/apply contract before deploying the replacement tenant state.

## Workflows
**IMPORTANT**: Translate tenant dataplane concepts into the bulk schema supported by the current Nornir MCP server.
**Layer 2 (VLAN Extend)**:
Map `vlans` (VLAN to VNI) and `evpn_rd_rt` (RD/RT targets) in a single bulk JSON payload. Include `interfaces` only when the approved Day-N transaction changes those ports; for Zero-to-Hero, use the access ports already supplied in Phase 1 through the server's deferred-port workflow.

**Layer 3 (Symmetric IRB)**:
For multi-device Symmetric IRB, include `vrfs`, `vlans`, `svis` (each VRF-bound SVI with `vrf` and `virtual_ip`, without `ip_address`), VXLAN, and RD/RT in one `configure_fabric_bulk` payload for the dataplane phase. Include interfaces only under the Day-N condition above; do not duplicate Zero-to-Hero access ports already handled in Phase 1. Do not call `configure_vrf` for this scenario.
Build one complete declarative tenant payload before the first dry-run; do not rely on schema retries to discover missing relationships between VRFs, VLANs, VNIs, SVIs, and EVPN policy.

## Post-Apply Handoff

1. Run `check_dataplane_summary` once for the intended VLAN/VNI/gateway. If it fails, stop and report the structured failure.
2. If it passes, ask the exact endpoint-verification approval question defined in `CLAUDE.md`. The question must be the final action in that turn; do not resolve, configure, or ping Linux clients before approval.
3. After approval, follow the exact Linux client setup, convergence wait, ping matrix, and completion sequence in `CLAUDE.md`.
