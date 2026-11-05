use hensou_desktop_protocol::{DesktopIcon, GridSpec, Point, ScreenLayout};
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, path::Path};
// Matches the protocol reference provider's logical cell dimensions.
pub const GRID: GridSpec = GridSpec {
    cell_width: 80,
    cell_height: 72,
};
#[derive(Default, Serialize, Deserialize)]
pub struct Positions {
    pub snap: bool,
    layouts: BTreeMap<String, BTreeMap<String, Point>>,
    latest: BTreeMap<String, Point>,
}
impl Positions {
    pub fn load(path: &Path) -> std::io::Result<Self> {
        match std::fs::read(path) {
            Ok(data) => serde_json::from_slice(&data).map_err(std::io::Error::other),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(Self::default()),
            Err(e) => Err(e),
        }
    }
    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let temp = path.with_extension("json.tmp");
        let mut file = std::fs::File::create(&temp)?;
        serde_json::to_writer(&mut file, self)?;
        file.sync_all()?;
        std::fs::rename(temp, path)
    }
    pub fn place(&mut self, screen: &ScreenLayout, icons: &mut [DesktopIcon]) {
        let key = key(screen);
        let positions = self.layouts.entry(key).or_default();
        let cells = cells(screen);
        let mut used = Vec::new();
        for icon in icons {
            let old = positions
                .get(&icon.id)
                .or_else(|| self.latest.get(&icon.id))
                .copied();
            let position = match old {
                Some(p) if inside(screen, p) => p,
                Some(p) => nearest(&cells, &used, p),
                None => first(&cells, &used),
            };
            used.push(position);
            icon.position = position;
            positions.insert(icon.id.clone(), position);
            self.latest.insert(icon.id.clone(), position);
        }
    }
    pub fn update(&mut self, screen: &ScreenLayout, icons: &[DesktopIcon]) {
        let positions = self.layouts.entry(key(screen)).or_default();
        for icon in icons {
            positions.insert(icon.id.clone(), icon.position);
            self.latest.insert(icon.id.clone(), icon.position);
        }
    }
}
fn key(screen: &ScreenLayout) -> String {
    format!(
        "{}:{}x{}@{}",
        screen.output, screen.width, screen.height, screen.scale
    )
}
pub fn inside(s: &ScreenLayout, p: Point) -> bool {
    i64::from(p.x) >= i64::from(s.usable.x)
        && i64::from(p.y) >= i64::from(s.usable.y)
        && i64::from(p.x) + i64::from(GRID.cell_width.min(s.usable.width))
            <= i64::from(s.usable.x) + i64::from(s.usable.width)
        && i64::from(p.y) + i64::from(GRID.cell_height.min(s.usable.height))
            <= i64::from(s.usable.y) + i64::from(s.usable.height)
}
pub fn cells(s: &ScreenLayout) -> Vec<Point> {
    let mut points = Vec::new();
    for col in 0..(s.usable.width / GRID.cell_width).max(1) {
        for row in 0..(s.usable.height / GRID.cell_height).max(1) {
            points.push(Point {
                x: s.usable.x + (col * GRID.cell_width) as i32,
                y: s.usable.y + (row * GRID.cell_height) as i32,
            });
        }
    }
    points
}
pub fn first(cells: &[Point], used: &[Point]) -> Point {
    cells
        .iter()
        .find(|p| !used.contains(p))
        .copied()
        .unwrap_or(cells[0])
}
pub fn nearest(cells: &[Point], used: &[Point], point: Point) -> Point {
    cells
        .iter()
        .filter(|p| !used.contains(p))
        .min_by_key(|p| {
            let x = i64::from(p.x) - i64::from(point.x);
            let y = i64::from(p.y) - i64::from(point.y);
            i128::from(x) * i128::from(x) + i128::from(y) * i128::from(y)
        })
        .copied()
        .unwrap_or(cells[0])
}
