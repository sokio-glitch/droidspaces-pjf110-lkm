# Droidspaces LKM for OnePlus Ace 3V (PJF110)

Device-specific, loadable-kernel-module port of
[Shikochin/Droidspaces-LKM](https://github.com/Shikochin/Droidspaces-LKM)
that lets [Droidspaces](https://github.com/ravindu644/Droidspaces-OSS) run
containers on the **stock** OnePlus Ace 3V kernel, without flashing a kernel.

- **Device:** OnePlus Ace 3V (PJF110), `qcom,cliffs`
- **Kernel:** `6.1.141-android14-11-o-g16e6ef702577` (KMI `android14-6.1`)
- **Root:** KernelSU with `ksud insmod` support

## What it provides

The stock vendor kernel compiles out PID namespaces, IPC namespaces, SysV IPC
and POSIX mqueue. This module supplies all of them from a loadable `.ko`:

- PID namespaces (create / nest / setns / PID 1 / procfs / container reboot)
- IPC namespaces + SysV IPC (msg / sem / shm)
- POSIX message queues
- the lifecycle hooks (fork/exit/nsproxy/perf/FUSE/cgroup/BPF) needed to keep
  namespace references correct

It is a **full-backend** port (the kernel has no native PID/IPC namespaces),
merged from upstream `port66`'s self-contained backend with `port61`'s 6.1
kernel APIs. See `src/port61ds/README.md`.

## Status / scope

**Core module: built, validated on-device, and installed for boot persistence.**
Verified on the target phone: PID-namespace creation (`unshare -p` → PID 1),
SysV IPC (`msgget`/`semget`/`shmget`) and a full POSIX-mqueue send/receive
round-trip (`mq_open` → `mq_send` → `mq_receive` → `mq_unlink`).
`droidspaces check` reports **all required features found** (Root, Linux
version, PID/mount/UTS/IPC namespaces, pivot_root, /proc, /sys, Seccomp).

### Optional extensions

- **devtmpfs** — ported to this 6.1 kernel and shipped as an **optional,
  experimental** separate module (`droidspaces_devtmpfs-pjf110.ko`, attached to
  the release). It is only useful for the hardware-access mode; the default
  containers use a tmpfs `/dev` and work without it. It has **not** been
  live-tested on the phone yet, and it inline-hooks `device_add`/`device_del`.
- **netfilter (nftables / xt_addrtype / IPv6 NAT), user namespaces
  (sandboxing), oplus PID-reference compat** — **not ported.** Upstream ships
  these only for 6.12 kernels (netfilter is a full vendored nftables, userns is
  ~30 `live-*` sources); porting them to 6.1 is a large, higher-risk effort and
  is not needed for normal container use.
- `--cpus` / `--pids-limit` remain unavailable: the stock kernel lacks
  `CFS_BANDWIDTH` / `CGROUP_PIDS`, which are core cgroup controllers that can
  only be added by flashing a kernel (e.g. a Wild Kernel build), not by an LKM.

### Not in scope (requires a real kernel build)

`Macvlan`, `IPv6 NAT`, `CPU limit`, `Process limit`, and sandboxing are marked
"optional" by `droidspaces check`; they need kernel config/controllers that a
loadable module cannot supply on this device.

## Safety — read before installing

- **Experimental.** It inline-hooks core kernel entry points. A wrong hook can
  crash or bootloop. Save your work before the first boot with it enabled.
- The loader only insmods when **both** the exact kernel release **and** the
  `/sys/kernel/btf/vmlinux` SHA-256 match the recorded device. Any kernel update
  changes the BTF and the module will refuse to load until rebuilt.
- Once activated the module **cannot be hot-unloaded**; disabling/uninstalling
  requires a reboot.
- If it misbehaves, boot with the module disabled in the KernelSU manager and
  collect `/data/adb/modules/droidspaces_pjf110/load.log` and `/sys/fs/pstore/`.

## Install

1. Download `Droidspaces-PJF110-LKM.zip` from the latest
   [Actions artifact](../../actions) or Release.
2. Install it in the **KernelSU manager** (Modules → Install from storage).
3. Reboot. The module description shows the load status; details are in
   `/data/adb/modules/droidspaces_pjf110/load.log`.
4. Verify: `su -c 'ls /proc/self/ns'` should now list `pid` and `ipc`, and
   `droidspaces check` should pass the namespace probes.

## Build

CI (`.github/workflows/build.yml`) builds inside the pinned
`ghcr.io/ylarod/ddk-min` android14-6.1 container, then:

- resolves every module import against the recorded device `kallsyms`,
- compares the module's BTF layouts against the recorded device BTF
  (`scripts/check-layout.py` allows only the known benign vendor field removals),
- packages the KernelSU module ZIP.

Reproduce locally with Docker:

```sh
docker run --rm --platform linux/amd64 -v "$PWD":/work -w /work \
  ghcr.io/ylarod/ddk-min:android14-6.1-20260313 bash scripts/build-pjf110.sh
```

## License

GPL-2.0-only, inheriting upstream Droidspaces-LKM and the Android common kernel
sources it transplants. See `LICENSE` and `src/port61ds/ORIGIN`.