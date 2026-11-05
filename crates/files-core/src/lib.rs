//! Files' real backend: local files, SSH through system OpenSSH (ADR 0005),
//! transfers, working copies and view memory. Implements
//! `hensou_files_model::FilesService`. Owned by the `core` worker.
