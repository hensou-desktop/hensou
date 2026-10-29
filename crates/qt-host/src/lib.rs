//! Native Qt host seam. This module owns I/O; Hensou QML owns appearance values.
mod theme;

pub use theme::qml::{configure_graphics, engine_has_roots, register_fonts};
