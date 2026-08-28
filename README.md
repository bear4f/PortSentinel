# PortSentinel

PortSentinel is an interactive Linux dual-stack port whitelist manager. It restricts access to selected local TCP and UDP ports with ordinary `iptables` and `ip6tables` rules. An address is allowed only when it appears directly in a rule or in an attached IP group; other traffic for that protected port is dropped.

PortSentinel does **not** hide traffic from network operators, provide anonymity, bypass filtering, inspect application protocols, or modify NAT, `FORWARD`, `OUTPUT`, `PREROUTING`, or `POSTROUTING`.

## Features

- IPv4 and IPv6 policies are generated and applied together.
- Single ports and inclusive ranges from `1` through `65535`.
- TCP, UDP, or TCP+UDP rules.
- Strict IPv4, IPv6, and CIDR validation through Python's `ipaddress` module.
- Reusable IP groups shared by any number of protected ports.
- Private `PORTSENTINEL` chains; no global firewall flushes.
- Staging-chain policy changes and paired rollback backups.
- SSH lockout warning based on `SSH_CONNECTION`/`SSH_CLIENT`, including non-standard SSH ports.
- Idempotent apply, `flock` serialization, `iptables -w 5`, dry run, systemd persistence, and one-command updates.
- Compatible with the normal `iptables` interface backed by either xtables or nftables.

## Compatibility

The supported targets are Debian 12/13 and Ubuntu 22.04/24.04 on amd64 and arm64. PortSentinel is a shell program and has no architecture-specific binary. It uses the distribution's existing `iptables` alternative; it never forces `iptables-legacy`.

Required tools are Bash, `iptables`, `ip6tables`, `ip`, `ss`, `flock`, `jq`, and Python 3. The installer obtains missing packages with `apt`.

## Installation

Review the installer before running it, then install from the default branch:

```bash
curl -fsSL https://raw.githubusercontent.com/bear4f/PortSentinel/main/install.sh -o install-portsentinel.sh
less install-portsentinel.sh
sudo bash install-portsentinel.sh
```

For a local checkout:

```bash
sudo PORTSENTINEL_SOURCE_DIR="$PWD" bash install.sh
```

Installation creates:

- `/usr/local/bin/portsentinel`
- `/usr/local/lib/portsentinel/uninstall.sh`
- `/etc/portsentinel/config.json`
- `/etc/portsentinel/portsentinel.conf`
- `/etc/portsentinel/backups/`
- `/etc/systemd/system/portsentinel.service`
- `/var/log/portsentinel.log` after the first loggable operation

The installer enables the service for future boots, but does not start it and does not add any firewall rule. Firewall changes happen only after a valid non-empty policy is explicitly applied.

## Quick start

```bash
sudo portsentinel
sudo portsentinel apply --dry-run
sudo portsentinel apply
sudo portsentinel status
```

The menu can create an IP group, add IPv4/IPv6 addresses or CIDRs, create a protected-port rule, show the expanded policy, create backups, restore a pair, reset private rules, or update PortSentinel.

## Configuration model

See [`examples/config.example.json`](examples/config.example.json). A rule contains a unique name, `tcp`, `udp`, or `both`, a port such as `10773` or `20000:20100`, attached groups, direct sources for each family, and a separate default for IPv4 and IPv6.

Valid source examples:

```text
IPv4:      192.0.2.10
IPv4 CIDR: 198.51.100.0/24
IPv6:      2001:db8::10
IPv6 CIDR: 2001:db8:1234::/48
```

IPv4 prefixes from `/0` through `/32` and IPv6 prefixes from `/0` through `/128` are supported. IPv4 values never reach `ip6tables`, and IPv6 values never reach `iptables`. Invalid values, duplicate names, missing groups, duplicate addresses, invalid ports, and overlapping protected port/protocol combinations are rejected before firewall access.

An IP group may contain both families and be attached to many ports. Adding an address to that group changes the effective policy for every attached rule on the next apply. Deleting a referenced group requires an explicit warning confirmation and detaches it from rules.

### Empty IPv6 whitelist

Every protected-port rule has an explicit `ipv6_default`. The interactive default is `drop`. Therefore a TCP/10773 rule with an IPv4 whitelist and no IPv6 sources still generates this IPv6 policy:

```text
ip6tables ... -A PORTSENTINEL_NEW -p tcp --dport 10773 -j DROP
```

This prevents an accidental IPv6 bypass. Choosing unrestricted access is deliberate and produces an explicit per-port `RETURN` rule.

## Firewall architecture

PortSentinel owns exactly one `PORTSENTINEL` chain in the IPv4 filter table and one in the IPv6 filter table. Each `INPUT` chain has one corresponding jump. Allowed sources receive `ACCEPT`, non-whitelisted traffic to a protected port receives `DROP`, and the private chain ends with `RETURN` so unrelated local ports continue through the host's existing firewall.

PortSentinel never runs `iptables -F`, `iptables -X`, `ip6tables -F`, or `ip6tables -X` without a private chain name. Docker, Fail2ban, UFW, SSH, and user rules are left in place. The execution position is the first rule in `INPUT`; PortSentinel protects only services terminating on this host.

### Transactional apply and rollback

`portsentinel apply` performs these steps under `/run/portsentinel.lock`:

1. Validate the complete JSON schema, addresses, ports, group references, and overlaps.
2. Generate complete IPv4 and IPv6 candidates.
3. Verify required backends before changing either family.
4. Save paired full-firewall backups with one UTC timestamp.
5. Build a complete `PORTSENTINEL_NEW` chain for IPv4.
6. Replace the existing `INPUT` jump with the staging jump, remove the unreferenced old private chain, and rename staging to `PORTSENTINEL`.
7. Repeat the switch for IPv6.
8. If either family fails or the process receives `INT`/`TERM` mid-transaction, restore both saved rulesets with `iptables-restore` and `ip6tables-restore`.

The staging chain is complete before it becomes reachable, so repeated applies are idempotent and do not accumulate jumps or rules. A whole-firewall restore is used only for rollback or an explicit restore—not during a normal apply.

If Linux reports IPv6 completely disabled, PortSentinel stores and validates the IPv6 policy, reports `IPv6: Disabled by system`, and skips the unavailable family without discarding the IPv4 policy. If IPv6 is enabled but its backend is missing or fails, preflight or rollback prevents a half-applied policy.

## SSH lockout protection

Before an interactive apply, PortSentinel parses the current client address and actual destination port from `SSH_CONNECTION` or `SSH_CLIENT`, then checks the listener with `ss -lntp` when available. It does not assume port 22. If a new TCP rule covers that port and its effective source networks do not contain the current client, PortSentinel displays a critical warning and cancels by default. Continuing without an exception requires typing the exact phrase `APPLY ANYWAY`.

Typing `PRESERVE CURRENT SSH` or passing `--preserve-current-ssh` adds the current source to the generated candidate for that protected TCP port only. It does not change `config.json`; therefore it lasts until the next apply. Non-interactive apply refuses a detected unsafe SSH session unless that explicit flag is present.

Also verify listening ports yourself with `ss -lntp` before protecting remote administration. Keep an independent rescue console available when changing any firewall.

## Dry run and inspection

```bash
sudo portsentinel apply --dry-run
sudo portsentinel effective
sudo portsentinel list
sudo portsentinel group list
```

Dry run validates the configuration and prints separate `===== IPv4 =====` and `===== IPv6 =====` candidate commands. It does not require root and does not touch firewall state. `effective` expands group membership and, when run as root with active chains, also displays packet and byte counters.

## Backup and restore

Every real apply creates a pair such as:

```text
/etc/portsentinel/backups/20260829-003000.ipv4.rules
/etc/portsentinel/backups/20260829-003000.ipv6.rules
```

The newest 20 pairs are retained by default. Create or restore explicitly with:

```bash
sudo portsentinel backup
sudo portsentinel restore 20260829-003000
```

Restore first creates a safety backup. If either restore command fails, PortSentinel attempts to reinstate that safety pair.

## Persistence

`portsentinel.service` is a `Type=oneshot` unit ordered after local filesystems and before `network-pre.target`. It pulls in that passive target, following systemd's documented ordering for firewall services, without waiting for `network-online.target`. It runs `portsentinel apply --non-interactive`; it does not depend on `iptables-persistent`. A missing or empty configuration causes a clean no-op, while errors are visible in the journal and `/var/log/portsentinel.log` where writable.

```bash
sudo systemctl status portsentinel
sudo journalctl -u portsentinel
```

## Update

Choose `[u] Update` in the interactive menu or run:

```bash
sudo portsentinel update
```

The command downloads the HTTPS installer to a temporary file, validates its Bash syntax and PortSentinel marker, and then runs its update mode. The update replaces only program/service files, preserves configuration and backups, reloads systemd metadata, and does not apply or restart the firewall policy automatically.

## Reset and uninstall

Reset removes only `INPUT -> PORTSENTINEL` jumps and PortSentinel's private chains. It keeps the program, configuration, and backups:

```bash
sudo portsentinel reset
```

Uninstall requires a second confirmation, disables the service, removes the same private rules and installed files, then asks whether `/etc/portsentinel` should be kept. The default is to retain it:

```bash
sudo portsentinel uninstall
```

Neither operation flushes an entire built-in chain.

## CLI reference

```text
portsentinel
portsentinel status
portsentinel list
portsentinel rule list
portsentinel group list
portsentinel effective
portsentinel apply [--dry-run] [--non-interactive]
portsentinel backup
portsentinel restore [TIMESTAMP]
portsentinel reset [--non-interactive]
portsentinel update
portsentinel uninstall
portsentinel version
```

## Testing

The default suite uses temporary configuration and dry-run/fake backends; it never modifies the host `INPUT` chain:

```bash
bash tests/run-tests.sh
```

CI runs Bash syntax checks, ShellCheck, strict address/port/config tests, group expansion, TCP/UDP/TCP+UDP generation, duplicate prevention, the empty-IPv6-list regression, and an idempotent fake-backend apply. A real network-namespace integration test is available only when explicitly enabled on Linux with root:

```bash
sudo PORTSENTINEL_RUN_NETNS=1 bash tests/test-netns.sh
```

## Security model and limitations

PortSentinel is a local `INPUT` access-control tool, not a complete firewall policy manager. An earlier host rule that accepts traffic before the PortSentinel jump, rules installed by another component later, or traffic not traversing local `INPUT` can change the result. Review `iptables -S INPUT` and `ip6tables -S INPUT` after deployment.

Configuration is root-owned (`0700` directory, `0600` JSON and backups). Inputs are passed as validated command arguments rather than evaluated shell text. Logs contain operation metadata, not credentials or secrets.

## License

MIT
