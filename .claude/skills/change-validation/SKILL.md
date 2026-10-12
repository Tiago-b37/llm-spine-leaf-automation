---
name: change-validation
description: >
  Verifies Data/Control Plane after config is applied.
  Triggers when the user says "test the config", "confirm if tenant is up",
  "validate the result", or asks for a post-execution audit.
---
# Change Validation

**Goal**: Actively verify Data/Control Plane after configuration application.

## Rules
0. Trigger Discipline & Phase Selection:
   - **Phases 1 & 2 (Underlay/EVPN)**: Run the intended lightweight exit gate after `apply`: `check_bgp_underlay_summary` for the eBGP thesis path, `check_ospf_summary` only for explicit OSPF designs, and `check_evpn_summary` for the overlay.
   - **Phase 3 (Dataplane/Ping)**: Run `check_dataplane_summary` once after `apply` as the lightweight fabric-state gate. Then pause and ask the user before Linux client setup, ping tests, or heavy diagnostics: *"Fabric deployment complete. Should I proceed with the final endpoint verification (Linux client setup & Pings)?"*. After approved setup and the required pings, finish without further MCP validation.
   - **Audit / Verify Requests**: If the user asks to audit, verify, validate, check, or confirm existing state, treat the task as read-only. A missing object/state is a finding, not permission to create or migrate it.
1. Matrix Check:
   - VLAN/SVI on leaf: `check_dataplane_summary` (preferred over per-interface queries).
   - BGP underlay: `check_bgp_underlay_summary(device_names=[...])` for the eBGP thesis path.
   - BGP/EVPN overlay: `check_evpn_summary(device_names=[...])` with the intended overlay devices.
   - OSPF: `check_ospf_summary(device_names=[...])` only when the selected underlay is OSPF.
2. Active Test: For Linux tenant clients, run live pings from the client containers with `docker exec <container> ping -q -c 3 <target>`, only after the user authorized endpoint testing. Do not run client reachability pings from the host namespace or from leaf devices.
3. Validation Gap Rule: A validation gap means a missing or insufficient check on existing intended state. It does not authorize creating missing network objects or changing live config unless the user explicitly asks for remediation.
4. Fallback: If verification fails, report the failure and ask the user whether to start `fabric-diagnostics`. Do not start broad raw-command troubleshooting in the main workflow.

## General Convergence & Telemetry Rules

1. **NO RAW CLI OVERLOAD:** Do not use `send_command` or `send_command_to_devices` for broad diagnostic protocol dumps during phase gates.
2. **USE SUMMARY TOOLS FIRST:** Prefer structured tools like `check_bgp_underlay_summary`, `check_ospf_summary`, `check_evpn_summary`, and `check_dataplane_summary`.
3. **POST-APPLY RETRY LOOP:** Only when a summary tool returns an empty or down state immediately after a successful apply:
   - Treat network convergence delay as the first post-apply hypothesis.
   - Wait (`sleep 10`) and retry the exact same summary tool.
   - Max retries: 3. If still failed, halt.
   - In a read-only audit or incident, treat the same state as fault evidence instead of assuming convergence.
4. **HARD STOP:** If Phase 1/2 exit gates are not met after 3 retries:
   - Stop automated progress.
   - Report the specific failure, for example "BGP underlay is 3/8 Established" or "OSPF is 0/4 Full".
   - Ask the user whether to start `fabric-diagnostics`.
   - Never proceed to the next phase while its gate is down; approval may authorize diagnosis or remediation, not skipping the gate.

## Phase 3 Validation Protocol

### Tool Selection
For Phase 3 dataplane validation, use:
- `check_dataplane_summary(device_names, expected_vni, expected_vlan, expected_gateway)`

This tool verifies:
- VXLAN VNI status
- VLAN configuration
- SVI line protocol status

### Validation Limits & Flow
1. **Apply** Phase 3 configuration via `configure_fabric_bulk` and `apply_fabric_dry_run`.
2. **Fabric Gate**: Invoke `check_dataplane_summary` exactly once as the fabric-state gate.
3. **Evaluate**:
   - If `phase3_ready` is `True`, ask the user for endpoint verification approval.
   - If `phase3_ready` is `False`, stop immediately, report the details, and ask for instructions.
4. **Stop & Ask**: Ask the user: *"Fabric deployment complete. Should I proceed with the final endpoint verification (Linux client setup & Pings)?"*.
5. **Configure Linux Clients**: After user approval, resolve the requested Linux client containers and configure them idempotently with `ip link set eth1 up`, `ip addr replace`, and `ip route replace`.
6. **Sleep**: Execute `sleep 15` in the shell to allow EVPN BGP routes to propagate.
7. **Endpoint Tests**: Run final container ping tests with `docker exec <container> ping -q -c 3`.
8. **Finish**: Report the ping results and finish the interactive run. Use `tests/validate_results.py` separately when comprehensive validation is required.

### Hard Stop Rules
- **NO ENDPOINT TESTS BEFORE LINUX IPs:** Do not run pings before Linux IPs are configured and the 15s sleep has completed. `check_dataplane_summary` is allowed before Linux setup because it validates fabric state, not endpoint reachability.
- **NO SUMMARY RETRY BY HABIT:** Do not retry `check_dataplane_summary` by habit. If the initial fabric gate fails, report the structured result and stop without automatic raw-command diagnostics.
- **NO CLI FALLBACK:** Do not use `send_command` or `send_command_to_devices` for `show vxlan`, `show vlan`, or `show ip interface` as a fallback inside the normal phase gate.
- **NO FRAGMENTATION:** Validate all participating leaves in one call.
