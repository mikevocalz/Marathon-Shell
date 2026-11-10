//! Marathon's apps: their manifests, packages and signatures, the catalogue
//! of what is installed, and installing and removing the user's.

pub mod apps;
pub mod archive;
mod cleanup;
pub mod install;
pub mod manifest;
pub mod paths;
pub use marathon_permissions as permissions;
#[cfg(test)]
mod lifecycle_tests;
pub mod signature;
mod transaction;
