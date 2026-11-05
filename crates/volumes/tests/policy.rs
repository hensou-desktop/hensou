use hensou_files_model::{FilesError, Volume, platform::VolumeMonitor};
use hensou_volumes::{Device, UdisksBackend, UdisksVolumes};
use std::{
    path::PathBuf,
    sync::{Arc, Mutex},
};
struct Bus {
    mounted: Mutex<Vec<String>>,
    powered_off: Mutex<bool>,
    busy: bool,
}
impl UdisksBackend for Bus {
    fn devices(&self) -> Result<Vec<Device>, FilesError> {
        Ok([("usb", true), ("internal", false)]
            .into_iter()
            .map(|(id, removable)| Device {
                volume: Volume {
                    id: id.into(),
                    label: id.into(),
                    mount_point: self
                        .mounted
                        .lock()
                        .unwrap()
                        .contains(&id.to_string())
                        .then(|| PathBuf::from("/run/media/test/USB")),
                    removable,
                    size: None,
                },
                drive: "drive".into(),
            })
            .collect())
    }
    fn mount(&self, id: &str) -> Result<PathBuf, FilesError> {
        self.mounted.lock().unwrap().push(id.into());
        Ok("/run/media/test/USB".into())
    }
    fn unmount(&self, id: &str) -> Result<(), FilesError> {
        if self.busy {
            return Err(FilesError::VolumeBusy {
                holders: vec!["editor".into()],
            });
        }
        self.mounted.lock().unwrap().retain(|v| v != id);
        Ok(())
    }
    fn power_off(&self, _: &str) -> Result<(), FilesError> {
        assert!(self.mounted.lock().unwrap().is_empty());
        *self.powered_off.lock().unwrap() = true;
        Ok(())
    }
}
#[test]
fn only_removable_media_automounts_and_eject_unmounts_before_poweroff() {
    let backend = Arc::new(Bus {
        mounted: Mutex::new(Vec::new()),
        powered_off: Mutex::new(false),
        busy: false,
    });
    let monitor = UdisksVolumes::new(backend.clone());
    assert_eq!(
        monitor
            .volumes()
            .iter()
            .map(|v| v.id.as_str())
            .collect::<Vec<_>>(),
        ["usb"]
    );
    assert_eq!(*backend.mounted.lock().unwrap(), ["usb"]);
    monitor.eject("usb").unwrap();
    assert!(*backend.powered_off.lock().unwrap());
}
#[test]
fn busy_volume_stays_mounted() {
    let backend = Arc::new(Bus {
        mounted: Mutex::new(vec!["usb".into()]),
        powered_off: Mutex::new(false),
        busy: true,
    });
    let monitor = UdisksVolumes::new(backend.clone());
    assert_eq!(
        monitor.eject("usb"),
        Err(FilesError::VolumeBusy {
            holders: vec!["editor".into()]
        })
    );
    assert_eq!(*backend.mounted.lock().unwrap(), ["usb"]);
    assert!(!*backend.powered_off.lock().unwrap());
}
