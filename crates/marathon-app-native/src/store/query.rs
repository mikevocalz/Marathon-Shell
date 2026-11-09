//! A cached observation with one owned refresh and one coalesced successor.

#[derive(Default)]
enum Refresh {
    #[default]
    Idle,
    Running,
    Again,
}

pub(super) struct Query<T> {
    pub value: Option<T>,
    pub error: Option<String>,
    refresh: Refresh,
}

impl<T> Default for Query<T> {
    fn default() -> Self {
        Self {
            value: None,
            error: None,
            refresh: Refresh::Idle,
        }
    }
}

impl<T> Query<T> {
    pub fn loading(&self) -> bool {
        !matches!(self.refresh, Refresh::Idle)
    }

    pub fn available(&self) -> bool {
        self.value.is_some() && self.error.is_none()
    }

    pub fn begin(&mut self) -> bool {
        if self.loading() {
            self.refresh = Refresh::Again;
            return false;
        }
        self.refresh = Refresh::Running;
        true
    }

    /// A refresh requested after this read started invalidates its result.
    /// Return true to issue the single coalesced successor before publishing.
    pub fn finish(&mut self, result: Result<T, String>) -> bool {
        let previous = std::mem::replace(&mut self.refresh, Refresh::Idle);
        if matches!(previous, Refresh::Again) {
            return true;
        }
        match result {
            Ok(value) => {
                self.value = Some(value);
                self.error = None;
            }
            Err(error) => self.error = Some(error),
        }
        false
    }
}

#[cfg(test)]
mod tests {
    use super::Query;

    #[test]
    fn an_empty_success_is_distinct_from_an_unavailable_query() {
        let mut query = Query::<Vec<String>>::default();
        assert!(!query.available());
        assert!(!query.loading());
        assert!(query.begin());
        assert!(query.loading());
        assert!(!query.finish(Ok(Vec::new())));
        assert!(query.available());
        assert!(!query.loading());
        assert_eq!(query.value, Some(Vec::new()));
    }

    #[test]
    fn a_failed_refresh_preserves_the_last_snapshot_and_can_recover() {
        let mut query = Query::default();
        assert!(query.begin());
        assert!(!query.finish(Ok(vec!["pending cleanup"])));
        assert!(query.begin());
        assert!(!query.finish(Err("service unavailable".into())));
        assert!(!query.available());
        assert_eq!(query.value, Some(vec!["pending cleanup"]));
        assert_eq!(query.error.as_deref(), Some("service unavailable"));
        assert!(query.begin());
        assert!(!query.finish(Ok(Vec::new())));
        assert!(query.available());
        assert_eq!(query.value, Some(Vec::new()));
        assert_eq!(query.error, None);
    }

    #[test]
    fn a_change_during_a_read_discards_the_old_reply_and_coalesces_requests() {
        let mut query = Query::default();
        assert!(query.begin());
        assert!(!query.finish(Ok(vec!["last known"])));
        assert!(query.begin());
        assert!(!query.begin());
        assert!(!query.begin());
        assert!(query.finish(Ok(vec!["obsolete"])));
        assert_eq!(query.value, Some(vec!["last known"]));
        assert!(query.begin());
        assert!(!query.finish(Ok(vec!["current"])));
        assert_eq!(query.value, Some(vec!["current"]));
        assert!(!query.loading());
    }
}
