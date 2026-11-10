//! Resolve confinement once, before choosing a cold or warm runner.

use std::env;
use std::ffi::OsStr;
use std::fmt;
use std::fs;
use std::io;
use std::os::unix::fs::PermissionsExt as _;

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) enum LaunchPolicy {
    /// The absolute executable path selected for this launch.
    Bubblewrap(String),
    DisabledByOverride,
}

impl LaunchPolicy {
    pub(crate) fn from_environment() -> Result<Self, PolicyError> {
        Self::resolve(
            env::var_os("MARATHON_DISABLE_SANDBOX").as_deref(),
            env::var_os("PATH").as_deref(),
        )
    }

    pub(super) fn resolve(
        disable: Option<&OsStr>,
        search_path: Option<&OsStr>,
    ) -> Result<Self, PolicyError> {
        if let Some(value) = disable {
            match value.to_str() {
                Some("0") => {}
                Some("1") => return Ok(Self::DisabledByOverride),
                Some(_) => return Err(PolicyError::InvalidOverride),
                None => return Err(PolicyError::NonUtf8Override),
            }
        }

        let executable = search_path.and_then(|path| {
            env::split_paths(path)
                .map(|directory| directory.join("bwrap"))
                .find(|candidate| {
                    fs::metadata(candidate).is_ok_and(|metadata| {
                        metadata.is_file() && metadata.permissions().mode() & 0o111 != 0
                    })
                })
        });
        let executable = executable.ok_or(PolicyError::MissingBubblewrap)?;
        // Empty or relative PATH entries must not turn into another PATH
        // lookup when QProcess or Command starts the selected executable.
        let executable = executable
            .canonicalize()
            .map_err(PolicyError::ResolveBubblewrap)?;
        let executable = executable
            .into_os_string()
            .into_string()
            .map_err(|_non_utf8_path| PolicyError::NonUtf8Executable)?;
        Ok(Self::Bubblewrap(executable))
    }

    pub(crate) fn is_sandboxed(&self) -> bool {
        matches!(self, Self::Bubblewrap(_))
    }

    /// A spare retains the policy under which it actually started.
    pub(crate) fn can_adopt(&self, spare: &Self) -> bool {
        self.is_sandboxed() && self == spare
    }
}

#[derive(Debug)]
pub(crate) enum PolicyError {
    InvalidOverride,
    NonUtf8Override,
    MissingBubblewrap,
    ResolveBubblewrap(io::Error),
    NonUtf8Executable,
}

impl fmt::Display for PolicyError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidOverride => f.write_str(
                "Invalid MARATHON_DISABLE_SANDBOX: expected unset, 0 or 1; refusing app launch",
            ),
            Self::NonUtf8Override => {
                f.write_str("MARATHON_DISABLE_SANDBOX is not UTF-8; refusing app launch")
            }
            Self::MissingBubblewrap => f.write_str(
                "Sandbox required but no executable bwrap was found in PATH; refusing app launch",
            ),
            Self::ResolveBubblewrap(error) => {
                write!(
                    f,
                    "Cannot resolve bwrap executable: {error}; refusing app launch"
                )
            }
            Self::NonUtf8Executable => {
                f.write_str("The bwrap executable path is not UTF-8; refusing app launch")
            }
        }
    }
}

impl std::error::Error for PolicyError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::ResolveBubblewrap(error) => Some(error),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;
    use std::ffi::OsString;
    use std::os::unix::ffi::OsStringExt as _;
    use std::os::unix::fs::symlink;
    use std::path::{Path, PathBuf};

    use super::*;

    fn executable(directory: &Path) -> io::Result<PathBuf> {
        fs::create_dir_all(directory)?;
        let path = directory.join("bwrap");
        fs::write(&path, b"test fixture, never executed")?;
        fs::set_permissions(&path, fs::Permissions::from_mode(0o755))?;
        Ok(path)
    }

    #[test]
    fn unset_and_zero_require_the_selected_executable() -> Result<(), Box<dyn Error>> {
        let directory = tempfile::tempdir()?;
        let path = executable(directory.path())?.canonicalize()?;
        let expected = LaunchPolicy::Bubblewrap(path.to_str().ok_or("non-UTF-8 fixture")?.into());
        for disable in [None, Some(OsStr::new("0"))] {
            assert_eq!(
                LaunchPolicy::resolve(disable, Some(directory.path().as_os_str()))?,
                expected
            );
        }
        Ok(())
    }

    #[test]
    fn only_exact_one_allows_launch_without_bubblewrap() -> Result<(), Box<dyn Error>> {
        let policy = LaunchPolicy::resolve(Some(OsStr::new("1")), None)?;
        assert_eq!(policy, LaunchPolicy::DisabledByOverride);
        assert!(!policy.is_sandboxed());
        Ok(())
    }

    #[test]
    fn malformed_overrides_are_errors() {
        for value in [
            "", "true", "false", "01", "00", "2", " 1", "1 ", "1\n", "0\n",
        ] {
            assert!(
                matches!(
                    LaunchPolicy::resolve(Some(OsStr::new(value)), None),
                    Err(PolicyError::InvalidOverride)
                ),
                "accepted override {value:?}"
            );
        }
    }

    #[test]
    fn non_utf8_override_is_an_error() {
        let value = OsString::from_vec(vec![0xff]);
        assert!(matches!(
            LaunchPolicy::resolve(Some(&value), None),
            Err(PolicyError::NonUtf8Override)
        ));
    }

    #[test]
    fn missing_bubblewrap_is_an_error_for_unset_and_zero() -> Result<(), Box<dyn Error>> {
        let directory = tempfile::tempdir()?;
        for disable in [None, Some(OsStr::new("0"))] {
            for path in [None, Some(directory.path().as_os_str())] {
                assert!(matches!(
                    LaunchPolicy::resolve(disable, path),
                    Err(PolicyError::MissingBubblewrap)
                ));
            }
        }
        Ok(())
    }

    #[test]
    fn a_directory_or_non_executable_file_is_not_bubblewrap() -> Result<(), Box<dyn Error>> {
        let directory = tempfile::tempdir()?;
        let path = directory.path().join("bwrap");
        fs::create_dir(&path)?;
        assert!(matches!(
            LaunchPolicy::resolve(None, Some(directory.path().as_os_str())),
            Err(PolicyError::MissingBubblewrap)
        ));
        fs::remove_dir(&path)?;
        fs::write(&path, b"not executable")?;
        fs::set_permissions(&path, fs::Permissions::from_mode(0o644))?;
        assert!(matches!(
            LaunchPolicy::resolve(None, Some(directory.path().as_os_str())),
            Err(PolicyError::MissingBubblewrap)
        ));
        Ok(())
    }

    #[test]
    fn path_search_skips_non_executables_and_keeps_first_executable() -> Result<(), Box<dyn Error>>
    {
        let directory = tempfile::tempdir()?;
        let first = directory.path().join("first");
        let second = directory.path().join("second");
        let third = directory.path().join("third");
        let first_path = executable(&first)?;
        fs::set_permissions(first_path, fs::Permissions::from_mode(0o644))?;
        let second_path = executable(&second)?.canonicalize()?;
        executable(&third)?;
        let search_path = env::join_paths([first, second, third])?;
        assert_eq!(
            LaunchPolicy::resolve(None, Some(&search_path))?,
            LaunchPolicy::Bubblewrap(second_path.to_str().ok_or("non-UTF-8 fixture")?.into())
        );
        Ok(())
    }

    #[test]
    fn spaces_and_symlinks_resolve_to_the_actual_executable() -> Result<(), Box<dyn Error>> {
        let directory = tempfile::tempdir()?;
        let actual = executable(&directory.path().join("directory with spaces"))?;
        let search = directory.path().join("search");
        fs::create_dir(&search)?;
        symlink(&actual, search.join("bwrap"))?;
        assert_eq!(
            LaunchPolicy::resolve(None, Some(search.as_os_str()))?,
            LaunchPolicy::Bubblewrap(actual.to_str().ok_or("non-UTF-8 fixture")?.into())
        );
        Ok(())
    }

    #[test]
    fn non_utf8_executable_path_is_refused_without_lossy_conversion() -> Result<(), Box<dyn Error>>
    {
        let directory = tempfile::tempdir()?;
        let search = directory.path().join(OsString::from_vec(vec![0xff]));
        executable(&search)?;
        assert!(matches!(
            LaunchPolicy::resolve(None, Some(search.as_os_str())),
            Err(PolicyError::NonUtf8Executable)
        ));
        Ok(())
    }

    #[test]
    fn warm_adoption_requires_the_same_confined_policy() {
        let required = LaunchPolicy::Bubblewrap("/usr/bin/bwrap".into());
        let different = LaunchPolicy::Bubblewrap("/opt/bin/bwrap".into());
        let disabled = LaunchPolicy::DisabledByOverride;
        assert!(required.can_adopt(&required));
        assert!(!required.can_adopt(&different));
        assert!(!required.can_adopt(&disabled));
        assert!(!disabled.can_adopt(&required));
        assert!(!disabled.can_adopt(&disabled));
    }
}
