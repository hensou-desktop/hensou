//! Native Qt host seam. This module owns I/O; Hensou QML owns appearance values.
mod theme;

pub use theme::qml::engine_has_roots;
