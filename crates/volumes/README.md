# udisks2 volumes

`UdisksVolumes::connect()` uses the blocking zbus system-bus API. The monitor owns
a worker thread and re-enumerates udisks2 every two seconds, so insertion and
external mounts are observed without requiring the host's async runtime.
`UdisksBackend` is the test seam for enumeration, Mount, Unmount and PowerOff.

Only removable devices are automounted. Unmounted internal filesystems are not
returned. udisks2 performs the mount as the caller; the result must be beneath
`/run/media/$USER` and owned by the effective uid. A nonconforming mount is
unmounted and rejected. The host must enable udisks2 and its user polkit policy.

Busy unmounts never call PowerOff. Best-effort process names come from readable
`/proc/*/fd` links, so process isolation can make the holder list incomplete.
Live device/polkit verification belongs to deployment; tests use a configured
backend and do not mount or power off the owner's devices.
