---
name: fabric-diagnostics
description: >
  Read-only root-cause investigation using bottom-up diagnostics. Load immediately
  when the user reports or suspects a connectivity, BGP, EVPN, VXLAN, interface,
  or dataplane fault and asks to investigate, diagnose, or find the root cause.
  Also load after explicit diagnostic approval when a failure is first discovered
  by change-validation or a phase gate. Do not use for routine healthy-state audits.
---
# Fabric Diagnostics

**Goal**: Investigate connectivity issues with the smallest evidence-driven path, falling back through lower layers whenever the current evidence does not establish them.

## Entry Point and Scope
- If the request or authoritative test context names the target devices, use them directly. If the active target set is missing, call `list_all_hosts` exactly once to resolve inventory names; do not call it merely to reconfirm known targets or after another tool already returned the target set.
- When the symptom identifies a protocol or layer, start with that layer's compact summary. A successful targeted response also establishes basic device reachability for that path. If a target is missing, unreachable, or times out, descend immediately to L0 and then work upward from the lowest unproven layer.
- When the symptom is generic or base reachability is itself in doubt, start at L0. Do not call both `list_all_hosts` and `get_fabric_health` only to discover the same device set.

## Diagnostic Reference
- Read [references/command-reference.md](references/command-reference.md) only when the current layer requires a specific infrastructure, structured-read, or EOS show command not already selected below.
- Do not load the reference for healthy phase gates or read it from top to bottom. Select only the entry that proves the current hypothesis.

## Diagnostic Layers
1. **L0 Base**: `get_fabric_health` or `clab inspect` when device/container reachability is unknown or a targeted read failed.
2. **L1 Physical**: `get_lldp_neighbors` and targeted `send_command` with `show interfaces status | json` when port state is needed.
3. **L2 MAC**: targeted `send_command` with `show mac address-table | json` only after L1 is healthy.
4. **L3 Underlay**: `check_bgp_underlay_summary` first for an underlay BGP symptom, or `check_ospf_summary` for an intended OSPF underlay; use `get_bgp_neighbors` only for targeted BGP follow-up.
5. **L4 Overlay EVPN**: `check_evpn_summary` first; use targeted `send_command` with `show vxlan vtep | json` or `show vxlan vni | json` only if the summary does not explain the failure.
6. **L5 Prefix/Data Plane**: `check_dataplane_summary` first; use targeted `send_command` with `show bgp evpn | json` or `show ip route vrf all | json` only for focused follow-up.

**Constraint**: Report findings briefly for each visited layer. Do NOT fire 10 tools at once.

## Evidence-to-Remediation Boundary
- Before proposing or applying remediation, tie the exact target object and desired value to observed evidence. Never infer configuration values from device names or naming patterns.
- After explicit approval, change only the object proven incorrect. Do not broaden the change to healthy peers, devices, or process-wide identity unless new read-only evidence proves that scope is necessary.
- If one targeted remediation does not converge, return to read-only validation and reassess the original hypothesis before changing anything else.
- Do not repeat applies or clear operational state as a substitute for correcting an unverified configuration value.
