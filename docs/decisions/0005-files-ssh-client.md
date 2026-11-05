# Files uses the system OpenSSH client

The owner chose system OpenSSH for Files on 2026-11-05. Files drives the `ssh` binary through the `openssh` crate (ControlMaster multiplexing) and speaks SFTP through `openssh-sftp-client`. The rejected option was pure-Rust russh with russh-sftp.

OpenSSH reads `~/.ssh/config`, keys and the agent exactly as the terminal does. Files does not parse or reimplement that configuration. The SSH Hosts list comes only from the concrete `Host` entries in `~/.ssh/config`. Files keeps no host list of its own.

Files connects with `StrictHostKeyChecking=yes`. For an unknown host, Files fetches the key with `ssh-keyscan` and shows its SHA256 fingerprint. Cancel is the default. Trust appends the key to `known_hosts`. The connect step then checks the stored key, so a key that changes between the scan and the connect fails the connection. Files never trusts a changed key. Files acts only as the SSH user. It has no sudo or root mode and stores no passwords.

Cost: Files depends on the `ssh` binary and on its process lifetimes, and errors arrive as stderr text that Files must classify. A later move to russh means rewriting the SSH backend and its tests, and it must keep the same `known_hosts` behaviour.
