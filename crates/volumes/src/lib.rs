//! udisks2 policy, with the bus isolated from removable-media decisions.
use hensou_files_model::{FilesError, Volume, platform::VolumeMonitor};
use std::{
    collections::HashMap,
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
    time::Duration,
};

#[derive(Clone, Debug)]
pub struct Device {
    pub volume: Volume,
    pub drive: String,
}
/// D-Bus seam: implementations must leave a busy filesystem mounted.
pub trait UdisksBackend: Send + Sync {
    fn devices(&self) -> Result<Vec<Device>, FilesError>;
    fn mount(&self, id: &str) -> Result<PathBuf, FilesError>;
    fn unmount(&self, id: &str) -> Result<(), FilesError>;
    fn power_off(&self, drive: &str) -> Result<(), FilesError>;
}
type Watch = Box<dyn Fn(Vec<Volume>) + Send + Sync>;
struct State {
    backend: Arc<dyn UdisksBackend>,
    watchers: Mutex<Vec<Watch>>,
    last: Mutex<Vec<Volume>>,
    operation: Mutex<()>,
}
pub struct UdisksVolumes {
    state: Arc<State>,
}
impl UdisksVolumes {
    pub fn connect() -> Result<Self, FilesError> {
        Ok(Self::new(Arc::new(SystemBus::connect()?)))
    }
    pub fn new(backend: Arc<dyn UdisksBackend>) -> Self {
        let state = Arc::new(State {
            backend,
            watchers: Mutex::new(Vec::new()),
            last: Mutex::new(Vec::new()),
            operation: Mutex::new(()),
        });
        let weak = Arc::downgrade(&state);
        std::thread::spawn(move || {
            loop {
                std::thread::sleep(Duration::from_secs(2));
                let Some(state) = weak.upgrade() else {
                    break;
                };
                if let Ok(volumes) = refresh(&state) {
                    let changed = {
                        let mut last = state.last.lock().unwrap();
                        if *last == volumes {
                            false
                        } else {
                            *last = volumes.clone();
                            true
                        }
                    };
                    if changed {
                        for watch in state.watchers.lock().unwrap().iter() {
                            watch(volumes.clone());
                        }
                    }
                }
            }
        });
        Self { state }
    }
    pub fn refresh(&self) -> Result<Vec<Volume>, FilesError> {
        refresh(&self.state)
    }
}
fn refresh(state: &State) -> Result<Vec<Volume>, FilesError> {
    let _guard = state.operation.lock().unwrap();
    let mut result = Vec::new();
    for mut device in state.backend.devices()? {
        if device.volume.removable && device.volume.mount_point.is_none() {
            device.volume.mount_point = state.backend.mount(&device.volume.id).ok();
        }
        if device.volume.mount_point.is_some() {
            result.push(device.volume);
        }
    }
    result.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(result)
}
impl VolumeMonitor for UdisksVolumes {
    fn volumes(&self) -> Vec<Volume> {
        self.refresh()
            .unwrap_or_else(|_| self.state.last.lock().unwrap().clone())
    }
    fn eject(&self, volume_id: &str) -> Result<(), FilesError> {
        let _guard = self.state.operation.lock().unwrap();
        let device = self
            .state
            .backend
            .devices()?
            .into_iter()
            .find(|d| d.volume.id == volume_id)
            .ok_or(FilesError::NotFound)?;
        self.state.backend.unmount(volume_id).map_err(|e| match e {
            FilesError::VolumeBusy { mut holders } => {
                if holders.is_empty()
                    && let Some(path) = &device.volume.mount_point
                {
                    holders = process_holders(path);
                }
                FilesError::VolumeBusy { holders }
            }
            other => other,
        })?;
        self.state.backend.power_off(&device.drive)
    }
    fn watch(&self, on_change: Watch) {
        self.state.watchers.lock().unwrap().push(on_change);
    }
}
fn process_holders(mount: &Path) -> Vec<String> {
    let mut holders = Vec::new();
    let Ok(processes) = std::fs::read_dir("/proc") else {
        return holders;
    };
    for process in processes.flatten() {
        if process
            .file_name()
            .to_string_lossy()
            .parse::<u32>()
            .is_err()
        {
            continue;
        }
        let Ok(fds) = std::fs::read_dir(process.path().join("fd")) else {
            continue;
        };
        if fds
            .flatten()
            .any(|fd| std::fs::read_link(fd.path()).is_ok_and(|p| p.starts_with(mount)))
        {
            holders.push(
                std::fs::read_to_string(process.path().join("comm"))
                    .unwrap_or_else(|_| process.file_name().to_string_lossy().into_owned())
                    .trim()
                    .to_string(),
            );
        }
    }
    holders.sort();
    holders.dedup();
    holders
}
fn bus_error(e: impl std::fmt::Display) -> FilesError {
    let message = e.to_string();
    if message.contains("DeviceBusy") {
        FilesError::VolumeBusy {
            holders: Vec::new(),
        }
    } else if message.contains("NotAuthorized") {
        FilesError::PermissionDenied
    } else {
        FilesError::Other { message }
    }
}
pub struct SystemBus {
    connection: zbus::blocking::Connection,
}
impl SystemBus {
    pub fn connect() -> Result<Self, FilesError> {
        Ok(Self {
            connection: zbus::blocking::Connection::system().map_err(bus_error)?,
        })
    }
    fn proxy<'a>(
        &'a self,
        path: &'a str,
        interface: &'a str,
    ) -> Result<zbus::blocking::Proxy<'a>, FilesError> {
        zbus::blocking::Proxy::new(&self.connection, "org.freedesktop.UDisks2", path, interface)
            .map_err(bus_error)
    }
}
impl UdisksBackend for SystemBus {
    fn devices(&self) -> Result<Vec<Device>, FilesError> {
        let manager = zbus::blocking::fdo::ObjectManagerProxy::builder(&self.connection)
            .destination("org.freedesktop.UDisks2")
            .map_err(bus_error)?
            .path("/org/freedesktop/UDisks2")
            .map_err(bus_error)?
            .build()
            .map_err(bus_error)?;
        let objects = manager.get_managed_objects().map_err(bus_error)?;
        let mut result = Vec::new();
        for (path, interfaces) in &objects {
            if !interfaces
                .keys()
                .any(|k| k.as_str() == "org.freedesktop.UDisks2.Filesystem")
            {
                continue;
            }
            let block = self.proxy(path.as_str(), "org.freedesktop.UDisks2.Block")?;
            if block.get_property::<bool>("HintIgnore").unwrap_or(false) {
                continue;
            }
            let drive: zbus::zvariant::OwnedObjectPath =
                block.get_property("Drive").map_err(bus_error)?;
            if drive.as_str() == "/" {
                continue;
            }
            let drive_proxy = self.proxy(drive.as_str(), "org.freedesktop.UDisks2.Drive")?;
            let removable = drive_proxy
                .get_property::<bool>("Removable")
                .unwrap_or(false)
                || drive_proxy
                    .get_property::<bool>("MediaRemovable")
                    .unwrap_or(false);
            let filesystem = self.proxy(path.as_str(), "org.freedesktop.UDisks2.Filesystem")?;
            let points: Vec<Vec<u8>> = filesystem.get_property("MountPoints").map_err(bus_error)?;
            use std::os::unix::ffi::OsStringExt;
            let points: Vec<PathBuf> = points
                .into_iter()
                .map(|mut bytes| {
                    if bytes.last() == Some(&0) {
                        bytes.pop();
                    }
                    PathBuf::from(std::ffi::OsString::from_vec(bytes))
                })
                .collect();
            // The system disk is the computer icon, not a volume.
            if is_system_mount(&points) {
                continue;
            }
            let mount_point = points.into_iter().next();
            let label: String = block.get_property("IdLabel").unwrap_or_default();
            result.push(Device {
                volume: Volume {
                    id: path.to_string(),
                    label: if label.is_empty() {
                        path.as_str().rsplit('/').next().unwrap_or("Volume").into()
                    } else {
                        label
                    },
                    mount_point,
                    removable,
                    size: block.get_property("Size").ok(),
                },
                drive: drive.to_string(),
            });
        }
        Ok(result)
    }
    fn mount(&self, id: &str) -> Result<PathBuf, FilesError> {
        let options: HashMap<&str, zbus::zvariant::Value<'_>> = HashMap::new();
        let path: String = self
            .proxy(id, "org.freedesktop.UDisks2.Filesystem")?
            .call("Mount", &(options,))
            .map_err(bus_error)?;
        let path = PathBuf::from(path);
        let user = std::env::var("USER").map_err(bus_error)?;
        use std::os::unix::fs::MetadataExt;
        let owner = nix::unistd::Uid::effective().as_raw();
        if !path.starts_with(Path::new("/run/media").join(user))
            || std::fs::metadata(&path).map_err(bus_error)?.uid() != owner
        {
            let _ = self.unmount(id);
            return Err(bus_error(
                "udisks2 returned a mount outside the user's /run/media directory",
            ));
        }
        Ok(path)
    }
    fn unmount(&self, id: &str) -> Result<(), FilesError> {
        let options: HashMap<&str, zbus::zvariant::Value<'_>> = HashMap::new();
        self.proxy(id, "org.freedesktop.UDisks2.Filesystem")?
            .call("Unmount", &(options,))
            .map_err(bus_error)
    }
    fn power_off(&self, drive: &str) -> Result<(), FilesError> {
        let options: HashMap<&str, zbus::zvariant::Value<'_>> = HashMap::new();
        self.proxy(drive, "org.freedesktop.UDisks2.Drive")?
            .call("PowerOff", &(options,))
            .map_err(bus_error)
    }
}

/// A filesystem that holds the running system: the root, the Nix store or
/// the boot partition. It belongs to the computer, never to a volume icon.
pub fn is_system_mount(points: &[PathBuf]) -> bool {
    points.iter().any(|p| {
        ["/", "/nix", "/nix/store", "/boot", "/efi", "/home", "/persist"]
            .iter()
            .any(|system| p == std::path::Path::new(system))
    })
}

#[cfg(test)]
mod system_mount_tests {
    use super::is_system_mount;
    use std::path::PathBuf;

    #[test]
    fn the_root_disk_is_not_a_volume() {
        let root: Vec<PathBuf> = ["/srv/games", "/", "/nix/store"].map(PathBuf::from).into();
        assert!(is_system_mount(&root));
        assert!(is_system_mount(&[PathBuf::from("/boot")]));
    }

    #[test]
    fn other_disks_and_media_are_volumes() {
        assert!(!is_system_mount(&[PathBuf::from("/run/media/simon/USB")]));
        assert!(!is_system_mount(&[PathBuf::from("/srv/media")]));
        assert!(!is_system_mount(&[]));
    }
}
