//! Native helpers that are plain C++ (see native.h).

#[cxx_qt::bridge]
pub mod ffi {
    unsafe extern "C++" {
        include!("native.h");
        /// Files stays resident after its windows close.
        #[namespace = "hensou_files"]
        fn keep_resident();
    }
}
