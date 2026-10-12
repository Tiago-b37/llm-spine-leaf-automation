---
name: intent-parser
description: >
  NLP engine that translates vague requests into structured intents.
  Triggers when the user asks for something in natural language (e.g.,
  "connect server X", "create a new tenant"). Must run before
  pre-deploy-validation to deduce IDs, VLANs, and interfaces.
---
# Intent Parser

**Goal**: Translate natural language into structured deployment parameters before configuration.

## Workflow
1. **Trigger**: For a mutating natural-language request, parse the intent before `pre-deploy-validation`. For a read-only request, use this skill only when the intent classification or requested validation scope is ambiguous; do not turn a clear audit or verification request into a configuration plan.
2. **Classify Intent Mode First**:
   - **Mutating**: requests to configure, create, migrate, change, remediate, fix, or apply.
   - **Read-only**: requests to audit, verify, validate, check, confirm, review, or inspect.
   - If the request is read-only, do not convert a missing object/state into a configuration plan. Report the gap or absence and stop unless the user explicitly asks for remediation.
3. **Translate Names**: Map concepts to technical variables via `naming-conventions`.
4. **Draft Internal Plan**: Record the requested configuration objects, their strictly required protocol dependencies, and the validation targets. Do not treat supported objects as requested scope. In particular, an L2VNI, VXLAN service, or anycast SVI does not implicitly request a VRF, L3VNI, or Symmetric IRB. Keep this internal unless a field is missing or ambiguous.
5. **Mandatory BGP Fields** (when BGP/EVPN is requested):
   - Peering type: interface-to-interface or loopback-to-loopback.
   - Update-source interface: mandatory `Loopback0` for loopback peering.
   - eBGP multihop: mandatory only when peering loopback-to-loopback between different ASNs. Omit it for directly connected eBGP underlay and iBGP.
   - Neighbor matrix: device, neighbor IP, local AS, remote AS.
6. **Mandatory VXLAN Fields**:
   - source_interface: mandatory `Loopback0` for VTEP source.
   - VNI mapping: VLAN to VNI.
   - replication type: if the user requests head-end replication/no multicast, include explicit `flood_vteps` for remote participating leaf VTEPs.
7. **Device Role Awareness**:
   - Use supplied prompt details and naming conventions first. Check `topology.json` or `clab inspect` only when runtime topology must be confirmed.
   - **Spines**: default thesis role is underlay transit only. Do not generate `vlans`, `vxlan`, `evpn_rd_rt`, `svis`, or `vrfs` for spines. Add EVPN overlay fields on spines only if the user explicitly requests route reflectors or route servers.
   - **Leaves**: VTEP/data-plane termination nodes. They receive only the VXLAN/VLAN/VTEP/SVI/VRF objects present in the approved intent and its strict dependencies.
   - **Access Ports**: Extract all host/client connections and place them inside the `interfaces` list of the Phase 1 payload for zero-to-hero, using `switchport_mode: access` and `access_vlan`. The server's Deferred-Guard will hold them and auto-inject in Phase 3.
8. **Underlay Routing Rules**:
   - The thesis default is eBGP underlay on directly connected spine-leaf P2P links plus Loopback0 advertisement via `bgp_networks[]`.
   - OSPF is a supported legacy/alternative path only when the user explicitly asks for OSPF.
   - If OSPF is selected, P2P fabric links must form adjacencies, Loopback0 should be passive, and access/client ports should not participate.
9. **Token Economy (Omission Rules)**:
   - **Strip Nulls**: Never output a key with a `null` value in JSON.
   - **Strip Defaults**: Do not output an unrequested key merely because its value matches the fabric default. Preserve every value explicitly required by the approved intent, including operational attributes such as MTU.
   - **Strip Empty**: Omit empty arrays `[]` and empty objects `{}`.
10. **Linux Node Constraints**:
   - Data interface must be `eth1`.
   - `eth0` is reserved for management and must be ignored.
11. **Fail Closed on Missing Intent**: If any mandatory field is missing and cannot be inferred from the active conventions, stop and ask for clarification.

## Output Contract

Before handing off to `pre-deploy-validation`, keep the structured intent compact and focused on:
- Scope: underlay / overlay / dataplane.
- Devices affected.
- Config objects: VLAN/VNI/VRF/SVI/interfaces/BGP peers.
- Validation targets for phase exit.
