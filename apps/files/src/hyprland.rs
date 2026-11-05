//! Window placement through Hyprland's IPC. A Wayland client cannot read or
//! set its own position, so Files asks the compositor after the window maps.
//! Without Hyprland every call is a quiet no-op and only sizes are restored.

use hensou_files_model::Geometry;
use serde_json::Value;
use std::io::{Read, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::time::Duration;

/// A monitor's logical rectangle in Hyprland's global layout.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Screen {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Client {
    pub address: String,
    pub geometry: Geometry,
    pub focus_order: i64,
}

fn socket() -> Option<PathBuf> {
    let signature = std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE")?;
    let mut candidates = Vec::new();
    if let Some(runtime) = std::env::var_os("XDG_RUNTIME_DIR") {
        candidates.push(PathBuf::from(runtime).join("hypr").join(&signature));
    }
    candidates.push(PathBuf::from("/tmp/hypr").join(&signature));
    candidates
        .into_iter()
        .map(|d| d.join(".socket.sock"))
        .find(|p| p.exists())
}

pub fn available() -> bool {
    socket().is_some()
}

fn request(command: &str) -> Option<String> {
    let mut stream = UnixStream::connect(socket()?).ok()?;
    stream.set_read_timeout(Some(Duration::from_millis(500))).ok()?;
    stream
        .set_write_timeout(Some(Duration::from_millis(500)))
        .ok()?;
    stream.write_all(command.as_bytes()).ok()?;
    let mut reply = String::new();
    stream.read_to_string(&mut reply).ok()?;
    Some(reply)
}

pub fn parse_screens(json: &str) -> Vec<Screen> {
    let Ok(Value::Array(monitors)) = serde_json::from_str::<Value>(json) else {
        return Vec::new();
    };
    monitors
        .iter()
        .filter_map(|m| {
            let scale = m["scale"].as_f64().filter(|s| *s > 0.0).unwrap_or(1.0);
            let (mut w, mut h) = (m["width"].as_f64()?, m["height"].as_f64()?);
            // Transforms 1, 3, 5 and 7 turn the output a quarter.
            if m["transform"].as_i64().unwrap_or(0) % 2 == 1 {
                std::mem::swap(&mut w, &mut h);
            }
            Some(Screen {
                x: m["x"].as_i64()? as i32,
                y: m["y"].as_i64()? as i32,
                width: (w / scale).round() as u32,
                height: (h / scale).round() as u32,
            })
        })
        .collect()
}

/// This process's mapped windows with the given title, most recently
/// focused first.
pub fn parse_clients(json: &str, pid: u32, title: &str) -> Vec<Client> {
    let Ok(Value::Array(clients)) = serde_json::from_str::<Value>(json) else {
        return Vec::new();
    };
    let mut found: Vec<Client> = clients
        .iter()
        .filter(|c| c["pid"].as_i64() == Some(pid as i64) && c["title"].as_str() == Some(title))
        .filter(|c| c["mapped"].as_bool().unwrap_or(true))
        .filter_map(|c| {
            Some(Client {
                address: c["address"].as_str()?.to_string(),
                geometry: Geometry {
                    x: c["at"][0].as_i64()? as i32,
                    y: c["at"][1].as_i64()? as i32,
                    width: c["size"][0].as_u64()? as u32,
                    height: c["size"][1].as_u64()? as u32,
                },
                focus_order: c["focusHistoryID"].as_i64().unwrap_or(i64::MAX),
            })
        })
        .collect();
    found.sort_by_key(|c| c.focus_order);
    found
}

/// Moves a remembered window back on screen. A window wholly inside one
/// screen stays where it was. Otherwise it goes to the screen it overlaps
/// most (the first screen if none), shrinks to fit and slides inside.
pub fn fit_on_screen(wanted: &Geometry, screens: &[Screen]) -> Geometry {
    let inside = |s: &Screen| {
        wanted.x >= s.x
            && wanted.y >= s.y
            && i64::from(wanted.x) + i64::from(wanted.width) <= i64::from(s.x) + i64::from(s.width)
            && i64::from(wanted.y) + i64::from(wanted.height)
                <= i64::from(s.y) + i64::from(s.height)
    };
    if screens.is_empty() || screens.iter().any(inside) {
        return wanted.clone();
    }
    let overlap = |s: &Screen| {
        let left = i64::from(wanted.x.max(s.x));
        let top = i64::from(wanted.y.max(s.y));
        let right = (i64::from(wanted.x) + i64::from(wanted.width))
            .min(i64::from(s.x) + i64::from(s.width));
        let bottom = (i64::from(wanted.y) + i64::from(wanted.height))
            .min(i64::from(s.y) + i64::from(s.height));
        (right - left).max(0) * (bottom - top).max(0)
    };
    let screen = screens
        .iter()
        .enumerate()
        .max_by_key(|(i, s)| (overlap(s), -(*i as i64)))
        .map(|(_, s)| *s)
        .unwrap_or(screens[0]);
    let width = wanted.width.min(screen.width);
    let height = wanted.height.min(screen.height);
    let max_x = screen.x + (screen.width - width) as i32;
    let max_y = screen.y + (screen.height - height) as i32;
    Geometry {
        x: wanted.x.clamp(screen.x, max_x),
        y: wanted.y.clamp(screen.y, max_y),
        width,
        height,
    }
}

/// The batch that floats, sizes and places one window.
pub fn placement_batch(address: &str, g: &Geometry) -> String {
    format!(
        "[[BATCH]]dispatch setfloating address:{a};dispatch resizewindowpixel exact {w} {h},address:{a};dispatch movewindowpixel exact {x} {y},address:{a}",
        a = address,
        w = g.width,
        h = g.height,
        x = g.x,
        y = g.y
    )
}

/// The window's current place, when Hyprland runs.
pub fn geometry(title: &str) -> Option<Geometry> {
    let clients = request("j/clients")?;
    parse_clients(&clients, std::process::id(), title)
        .into_iter()
        .next()
        .map(|c| c.geometry)
}

/// Places a just-mapped window, on a background thread. The window may take
/// a moment to appear in Hyprland's client list, so it retries briefly.
pub fn place(title: String, wanted: Geometry) {
    if !available() {
        return;
    }
    std::thread::spawn(move || {
        for _ in 0..20 {
            if let Some(clients) = request("j/clients") {
                if let Some(client) = parse_clients(&clients, std::process::id(), &title)
                    .into_iter()
                    .next()
                {
                    let screens = request("j/monitors")
                        .map(|m| parse_screens(&m))
                        .unwrap_or_default();
                    let fitted = fit_on_screen(&wanted, &screens);
                    let _ = request(&placement_batch(&client.address, &fitted));
                    return;
                }
            }
            std::thread::sleep(Duration::from_millis(50));
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;

    const SCREENS: [Screen; 2] = [
        Screen {
            x: 0,
            y: 0,
            width: 1280,
            height: 800,
        },
        Screen {
            x: 1280,
            y: 0,
            width: 1920,
            height: 1080,
        },
    ];

    fn g(x: i32, y: i32, width: u32, height: u32) -> Geometry {
        Geometry {
            x,
            y,
            width,
            height,
        }
    }

    #[test]
    fn a_window_that_fits_stays_put() {
        assert_eq!(fit_on_screen(&g(100, 50, 600, 400), &SCREENS), g(100, 50, 600, 400));
        assert_eq!(fit_on_screen(&g(1400, 60, 900, 700), &SCREENS), g(1400, 60, 900, 700));
    }

    #[test]
    fn a_window_from_a_missing_screen_comes_back() {
        // Remembered on a third screen that is gone: the first screen takes it.
        assert_eq!(fit_on_screen(&g(4000, 200, 600, 400), &SCREENS), g(680, 200, 600, 400));
        assert_eq!(fit_on_screen(&g(-900, -50, 600, 400), &SCREENS), g(0, 0, 600, 400));
    }

    #[test]
    fn a_window_across_an_edge_slides_onto_the_screen_it_mostly_covers() {
        assert_eq!(fit_on_screen(&g(1100, 700, 600, 400), &SCREENS), g(1280, 680, 600, 400));
    }

    #[test]
    fn a_window_larger_than_its_screen_shrinks_to_fit() {
        assert_eq!(fit_on_screen(&g(10, 10, 3000, 2000), &SCREENS[..1]), g(0, 0, 1280, 800));
    }

    #[test]
    fn monitors_report_logical_sizes() {
        let json = r#"[{"x":0,"y":0,"width":2880,"height":1800,"scale":1.5,"transform":0},
                       {"x":1920,"y":0,"width":1080,"height":1920,"scale":1.0,"transform":1}]"#;
        assert_eq!(
            parse_screens(json),
            vec![
                Screen { x: 0, y: 0, width: 1920, height: 1200 },
                Screen { x: 1920, y: 0, width: 1920, height: 1080 }
            ]
        );
    }

    #[test]
    fn clients_match_this_process_and_title_newest_focus_first() {
        let json = r#"[
          {"address":"0xa","pid":7,"title":"Documents","at":[10,20],"size":[300,200],"focusHistoryID":3},
          {"address":"0xb","pid":7,"title":"Documents","at":[40,50],"size":[500,400],"focusHistoryID":0},
          {"address":"0xc","pid":8,"title":"Documents","at":[0,0],"size":[1,1],"focusHistoryID":1}]"#;
        let found = parse_clients(json, 7, "Documents");
        assert_eq!(found.len(), 2);
        assert_eq!(found[0].address, "0xb");
        assert_eq!(found[0].geometry, g(40, 50, 500, 400));
    }

    #[test]
    fn placement_floats_then_sizes_then_moves() {
        assert_eq!(
            placement_batch("0xb", &g(5, 6, 7, 8)),
            "[[BATCH]]dispatch setfloating address:0xb;dispatch resizewindowpixel exact 7 8,address:0xb;dispatch movewindowpixel exact 5 6,address:0xb"
        );
    }
}
