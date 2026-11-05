use hensou_desktop_protocol::{DesktopIcon, GridSpec, Point, ScreenLayout, Theme};
use serde::{Deserialize, Serialize};
use std::{collections::BTreeMap, path::Path};
// Period spacing is supplied by the provider, not guessed by shell clients.
pub fn grid(theme: Theme) -> GridSpec {
    match theme {
        Theme::Platinum => GridSpec {
            cell_width: 80,
            cell_height: 72,
        },
        Theme::Memphis => GridSpec {
            cell_width: 100,
            cell_height: 100,
        },
    }
}
fn theme_name(theme: Theme) -> &'static str {
    match theme {
        Theme::Platinum => "platinum",
        Theme::Memphis => "memphis",
    }
}
fn icon_key(theme: Theme, id: &str) -> String {
    format!("{}:{id}", theme_name(theme))
}
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
    pub fn place(&mut self, theme: Theme, screen: &ScreenLayout, icons: &mut [DesktopIcon]) {
        let key = key(theme, screen);
        let grid = grid(theme);
        let positions = self.layouts.entry(key).or_default();
        let cells = cells(screen, grid);
        let mut used = Vec::new();
        for icon in icons {
            let old = positions
                .get(&icon.id)
                .or_else(|| self.latest.get(&icon_key(theme, &icon.id)))
                .copied();
            let position = match old {
                Some(p)
                    if inside(screen, p, grid)
                        || (used.len() >= cells.len() && origin_inside(screen, p)) =>
                {
                    p
                }
                Some(p) => nearest(&cells, &used, p, screen, grid),
                None => first(&cells, &used, screen, grid),
            };
            used.push(position);
            icon.position = position;
            positions.insert(icon.id.clone(), position);
            self.latest.insert(icon_key(theme, &icon.id), position);
        }
    }
    pub fn update(&mut self, theme: Theme, screen: &ScreenLayout, icons: &[DesktopIcon]) {
        let positions = self.layouts.entry(key(theme, screen)).or_default();
        for icon in icons {
            positions.insert(icon.id.clone(), icon.position);
            self.latest.insert(icon_key(theme, &icon.id), icon.position);
        }
    }
}
fn key(theme: Theme, screen: &ScreenLayout) -> String {
    format!(
        "{}:{}:{}x{}@{}",
        theme_name(theme),
        screen.output,
        screen.width,
        screen.height,
        screen.scale
    )
}
pub fn inside(s: &ScreenLayout, p: Point, grid: GridSpec) -> bool {
    i64::from(p.x) >= i64::from(s.usable.x)
        && i64::from(p.y) >= i64::from(s.usable.y)
        && i64::from(p.x) + i64::from(grid.cell_width.min(s.usable.width))
            <= i64::from(s.usable.x) + i64::from(s.usable.width)
        && i64::from(p.y) + i64::from(grid.cell_height.min(s.usable.height))
            <= i64::from(s.usable.y) + i64::from(s.usable.height)
}
pub fn cells(s: &ScreenLayout, grid: GridSpec) -> Vec<Point> {
    let mut points = Vec::new();
    for col in 0..(s.usable.width / grid.cell_width).max(1) {
        for row in 0..(s.usable.height / grid.cell_height).max(1) {
            points.push(Point {
                x: s.usable.x + (col * grid.cell_width) as i32,
                y: s.usable.y + (row * grid.cell_height) as i32,
            });
        }
    }
    points
}
pub fn first(cells: &[Point], used: &[Point], screen: &ScreenLayout, grid: GridSpec) -> Point {
    cells
        .iter()
        .find(|p| !occupied(**p, used, grid))
        .copied()
        .unwrap_or_else(|| overflow(cells, used, screen))
}
pub fn nearest(
    cells: &[Point],
    used: &[Point],
    point: Point,
    screen: &ScreenLayout,
    grid: GridSpec,
) -> Point {
    cells
        .iter()
        .filter(|p| !occupied(**p, used, grid))
        .min_by_key(|p| {
            let x = i64::from(p.x) - i64::from(point.x);
            let y = i64::from(p.y) - i64::from(point.y);
            i128::from(x) * i128::from(x) + i128::from(y) * i128::from(y)
        })
        .copied()
        .unwrap_or_else(|| overflow(cells, used, screen))
}

fn origin_inside(s: &ScreenLayout, p: Point) -> bool {
    i64::from(p.x) >= i64::from(s.usable.x)
        && i64::from(p.y) >= i64::from(s.usable.y)
        && i64::from(p.x) < i64::from(s.usable.x) + i64::from(s.usable.width)
        && i64::from(p.y) < i64::from(s.usable.y) + i64::from(s.usable.height)
}
// The coordinator's overflow rule: 12px cascade, then 6px inset on wrap.
fn overflow(cells: &[Point], used: &[Point], screen: &ScreenLayout) -> Point {
    let last = cells[cells.len() - 1];
    let n = used.len().saturating_sub(cells.len()) as i64 + 1;
    let offset = n * 12;
    let x = i64::from(last.x) + offset;
    let y = i64::from(last.y) + offset;
    let right = i64::from(screen.usable.x) + i64::from(screen.usable.width);
    let bottom = i64::from(screen.usable.y) + i64::from(screen.usable.height);
    if x < right && y < bottom {
        return Point {
            x: x as i32,
            y: y as i32,
        };
    }
    let capacity =
        ((right - i64::from(last.x) - 1).min(bottom - i64::from(last.y) - 1) / 12).max(0);
    let wrapped = 6 + (n - capacity - 1) * 12;
    Point {
        x: screen.usable.x + (wrapped % i64::from(screen.usable.width)) as i32,
        y: screen.usable.y + (wrapped % i64::from(screen.usable.height)) as i32,
    }
}

fn occupied(cell: Point, used: &[Point], grid: GridSpec) -> bool {
    used.iter().any(|p| {
        (i64::from(p.x) - i64::from(cell.x)).abs() < i64::from(grid.cell_width)
            && (i64::from(p.y) - i64::from(cell.y)).abs() < i64::from(grid.cell_height)
    })
}
