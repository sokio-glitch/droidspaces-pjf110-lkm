# OnePlus PJF110 (Ace 3V) / android14-6.1 device port

Device-specific source set for the OnePlus Ace 3V (PJF110, `qcom,cliffs`),
kernel `6.1.141-android14-11-o-g16e6ef702577` (KMI `android14-6.1`).

The stock vendor kernel compiles out PID namespaces, IPC namespaces, SysV IPC
and POSIX mqueue, so this is a **full-backend** port: it supplies its own
`init_ipc_ns`, `mq_lock`, PID/IPC namespace lifecycle, SysV IPC (msg/sem/shm)
and POSIX mqueue, rather than reusing native objects.

## How it was merged

Base: upstream `src/port66` (the self-contained full-backend model, which matches
a kernel with no native PID/IPC namespaces). The 6.6-specific kernel APIs were
then reverted to their 6.1 equivalents using upstream `src/port61` as the
reference:

- `fork.c`, `exit.c`, `pid.c`, `nsproxy.c`, `shm.c`, `sem.c`, `proc_root.c`,
  `memfd.c` taken from `src/port61` (6.1 API: `atomic_set` nsproxy count,
  `fget`/`fput` setns, `mmgrab`, 8-arg `do_mmap`, `do_munmap`+`mas_pause`,
  pointer `semadj`, `kfree` proc fs_info, memfd noexec stub).
- `ipc.c`: free path uses `kern_unmount()` (6.1) instead of
  `mnt_make_shortterm()`+`mntput()` (6.6).
- `ipc_sysctl.c`, `mq_sysctl.c`: 3-arg `__register_sysctl_table()` (6.1).
- `mqueue.c`: `inode_set_ctime_current()` rewritten as
  `i_ctime = current_time()` (mainline 6.1 idiom).
- `hooks.c`: dropped the 6.6-only `exec_task_namespaces` hook and the
  `memfd_create` syscall hook (6.1 has no per-PID-ns memfd noexec policy).
- `main.c`: gated on the recorded PJF110 compatible + exact release.

Files identical between upstream `port61` and `port66` (msg.c, msgutil.c,
ipc-compat.c, pid_alloc.c, proc_ns.c, reboot.c, fuse.c, perf.c, bpf-pidns.c,
selftest.c) are 6.1-safe as-is. `cgroup-pidlist.c` keeps the port66 binary-search
fix.

## Upstream provenance

Derived from Shikochin/Droidspaces-LKM (GPL-2.0). The transplanted subsystems
originate from the Android common kernel; see the upstream `src/port66/ORIGIN`
and `src/port61/ORIGIN` for the per-file source hashes. This port is experimental
and has NOT yet been validated on the physical device.