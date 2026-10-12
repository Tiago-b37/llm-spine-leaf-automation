# Diagnostic Command Reference

Use this reference only after `fabric-diagnostics` is active and the current
bottom-up layer requires evidence not provided by its preferred summary tool.
All EOS commands listed here are read-only. Never use this reference to push
configuration or to collect broad state for completeness.

## Infrastructure facts (shell)

Use shell only for Containerlab/container facts outside the routers.

| Question | Command |
|---|---|
| Which devices are running? | `clab inspect -f json` |
| How many routers are running? | `docker ps --format '{{.Names}}' \| grep -E '(spine|leaf)' \| wc -l` |
| Is a specific container running? | `docker inspect <container-name> --format '{{.State.Running}}'` |
| What is a node's management IP? | `clab inspect -f json` and select the canonical node name |
| Show container logs | `docker logs <container-name>` |
| Reconfigure the lab | `clab deploy -t dc2-topology.clab.yml --reconfigure` — only when explicitly requested |
| Destroy the lab | `clab destroy -t dc2-topology.clab.yml` — only when explicitly requested |

Do not run Linux or EOS CLI commands through `docker exec` on cEOS routers.
Router state must come from Nornir MCP.

## Structured Nornir reads

Prefer these tools before raw EOS commands.

| Evidence required | Tool |
|---|---|
| eBGP underlay state on all intended devices | `check_bgp_underlay_summary(device_names)` |
| OSPF adjacency state for an OSPF underlay | `check_ospf_summary(device_names)` |
| EVPN session state on intended overlay devices | `check_evpn_summary(device_names)` |
| VNI/VLAN/SVI dataplane state | `check_dataplane_summary(device_names, expected_vni, expected_vlan, expected_gateway)` |
| Interface addresses | `get_interfaces_ip` |
| Physical neighbors | `get_lldp_neighbors` |
| BGP neighbor summary | `get_bgp_neighbors` |
| One BGP neighbor in detail | `get_bgp_neighbors_detail` |
| BGP configuration | `get_bgp_config` |
| ARP state | `get_arp_table` |
| Network instances | `get_network_instances` |

For evidence across several devices, prefer one summary tool. If no structured
tool can prove the required fact, use one targeted
`send_command_to_devices` call instead of repeated per-device reads.

## Targeted EOS show commands

Use `send_command` only when the structured tools above cannot explain the
failure. Query the smallest object needed for the current diagnostic layer.

| Evidence required | Read-only EOS command |
|---|---|
| EVPN routes (MAC/IP, Type 2/5) | `show bgp evpn \| json` |
| VTEP interface state | `show interfaces vxlan 1 \| json` |
| Remote VTEP reachability | `show vxlan vtep \| json` |
| VXLAN MAC-to-VTEP mapping | `show vxlan address-table \| json` |
| L2/L3 VNI mappings | `show vxlan vni \| json` |
| VRF state | `show vrf \| json` |
| Routing table across VRFs | `show ip route vrf all \| json` |
| VLAN state | `show vlan \| json` |
| MLAG state | `show mlag \| json` |
| Port status | `show interfaces status \| json` |
| Interface counters | `show interfaces counters \| json` |
| MAC address table | `show mac address-table \| json` |

The `send_command` policy in `CLAUDE.md` remains authoritative. Do not use
`configure`, `conf t`, `no ...`, reload, save, or copy commands through
`send_command`. A `clear ...` operation still requires explicit user
confirmation in the same interaction.
