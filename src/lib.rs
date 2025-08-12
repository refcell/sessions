//! Session counter library for Claude Code hook system
//!
//! This library provides utilities for tracking active Claude Code sessions
//! using a JSON configuration file with file locking for concurrent access.

use anyhow::{Context, Result};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::PathBuf;

/// Configuration structure for session tracking
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct SessionConfig {
    /// Current count of active sessions
    pub count: u32,
    /// Timestamp of last update in UTC
    pub last_updated: DateTime<Utc>,
    /// Optional list of session IDs for detailed tracking
    pub sessions: Vec<String>,
}

impl Default for SessionConfig {
    fn default() -> Self {
        Self {
            count: 0,
            last_updated: Utc::now(),
            sessions: Vec::new(),
        }
    }
}

impl SessionConfig {
    /// Create a new session config with current timestamp
    pub fn new() -> Self {
        Self::default()
    }

    /// Increment the session count by 1
    pub fn increment(&mut self) {
        self.count = self.count.saturating_add(1);
        self.last_updated = Utc::now();
    }

    /// Decrement the session count by 1, ensuring it doesn't go below 0
    pub fn decrement(&mut self) {
        self.count = self.count.saturating_sub(1);
        self.last_updated = Utc::now();
    }

    /// Add a session ID to the tracking list
    pub fn add_session(&mut self, session_id: String) {
        if !self.sessions.contains(&session_id) {
            self.sessions.push(session_id);
        }
    }

    /// Remove a session ID from the tracking list
    pub fn remove_session(&mut self, session_id: &str) {
        self.sessions.retain(|id| id != session_id);
    }
}

/// Get the path to the session count configuration file
pub fn get_config_path() -> Result<PathBuf> {
    let home_dir = dirs::home_dir().context("Failed to get home directory")?;
    Ok(home_dir.join(".sessions.json"))
}

/// Read the session configuration from file with file locking
pub fn read_config() -> Result<SessionConfig> {
    let config_path = get_config_path()?;

    // If file doesn't exist, return default config
    if !config_path.exists() {
        return Ok(SessionConfig::default());
    }

    let mut file = File::open(&config_path)
        .with_context(|| format!("Failed to open config file: {}", config_path.display()))?;

    // Lock the file for reading
    #[cfg(unix)]
    {
        // Advisory lock - other processes should respect it
        nix_flock(&file, nix::fcntl::FlockArg::LockShared)?;
    }

    let mut contents = String::new();
    file.read_to_string(&mut contents)
        .context("Failed to read config file")?;

    if contents.trim().is_empty() {
        return Ok(SessionConfig::default());
    }

    let config: SessionConfig =
        serde_json::from_str(&contents).context("Failed to parse config JSON")?;

    Ok(config)
}

/// Write the session configuration to file with file locking
pub fn write_config(config: &SessionConfig) -> Result<()> {
    let config_path = get_config_path()?;

    // Ensure parent directory exists
    if let Some(parent) = config_path.parent() {
        std::fs::create_dir_all(parent).context("Failed to create config directory")?;
    }

    // Open file for writing, create if doesn't exist
    let mut file = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&config_path)
        .with_context(|| {
            format!(
                "Failed to open config file for writing: {}",
                config_path.display()
            )
        })?;

    // Lock the file for writing
    #[cfg(unix)]
    {
        nix_flock(&file, nix::fcntl::FlockArg::LockExclusive)?;
    }

    let json_content =
        serde_json::to_string_pretty(config).context("Failed to serialize config to JSON")?;

    file.write_all(json_content.as_bytes())
        .context("Failed to write config to file")?;

    file.sync_all().context("Failed to sync file to disk")?;

    Ok(())
}

/// Atomically update the session configuration
pub fn update_config<F>(mut updater: F) -> Result<SessionConfig>
where
    F: FnMut(&mut SessionConfig),
{
    let config_path = get_config_path()?;

    // Ensure parent directory exists
    if let Some(parent) = config_path.parent() {
        std::fs::create_dir_all(parent).context("Failed to create config directory")?;
    }

    // Open or create the file
    let mut file = OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false) // We'll manually truncate after reading
        .open(&config_path)
        .with_context(|| format!("Failed to open config file: {}", config_path.display()))?;

    // Lock the file exclusively
    #[cfg(unix)]
    {
        nix_flock(&file, nix::fcntl::FlockArg::LockExclusive)?;
    }

    // Read current config
    let mut contents = String::new();
    file.read_to_string(&mut contents)
        .context("Failed to read config file")?;

    let mut config = if contents.trim().is_empty() {
        SessionConfig::default()
    } else {
        serde_json::from_str(&contents).context("Failed to parse config JSON")?
    };

    // Apply the update
    updater(&mut config);

    // Write back to file
    file.seek(SeekFrom::Start(0))
        .context("Failed to seek to start of file")?;

    file.set_len(0).context("Failed to truncate file")?;

    let json_content =
        serde_json::to_string_pretty(&config).context("Failed to serialize config to JSON")?;

    file.write_all(json_content.as_bytes())
        .context("Failed to write config to file")?;

    file.sync_all().context("Failed to sync file to disk")?;

    Ok(config)
}

#[cfg(unix)]
fn nix_flock(file: &File, arg: nix::fcntl::FlockArg) -> Result<()> {
    use std::os::unix::io::AsRawFd;
    #[allow(deprecated)]
    {
        nix::fcntl::flock(file.as_raw_fd(), arg).context("Failed to acquire file lock")?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[allow(dead_code)] // Helper function for potential future tests
    fn setup_test_config_path(temp_dir: &TempDir) -> PathBuf {
        temp_dir.path().join(".sessions.json")
    }

    #[test]
    fn test_session_config_new() {
        let config = SessionConfig::new();
        assert_eq!(config.count, 0);
        assert!(config.sessions.is_empty());
    }

    #[test]
    fn test_session_config_increment() {
        let mut config = SessionConfig::new();
        let initial_time = config.last_updated;

        // Small delay to ensure timestamp changes
        std::thread::sleep(std::time::Duration::from_millis(1));

        config.increment();
        assert_eq!(config.count, 1);
        assert!(config.last_updated > initial_time);

        config.increment();
        assert_eq!(config.count, 2);
    }

    #[test]
    fn test_session_config_decrement() {
        let mut config = SessionConfig::new();
        config.count = 2;

        config.decrement();
        assert_eq!(config.count, 1);

        config.decrement();
        assert_eq!(config.count, 0);

        // Should not go below 0
        config.decrement();
        assert_eq!(config.count, 0);
    }

    #[test]
    fn test_session_config_add_remove_session() {
        let mut config = SessionConfig::new();

        config.add_session("session-1".to_string());
        assert_eq!(config.sessions.len(), 1);
        assert!(config.sessions.contains(&"session-1".to_string()));

        // Adding same session should not duplicate
        config.add_session("session-1".to_string());
        assert_eq!(config.sessions.len(), 1);

        config.add_session("session-2".to_string());
        assert_eq!(config.sessions.len(), 2);

        config.remove_session("session-1");
        assert_eq!(config.sessions.len(), 1);
        assert!(!config.sessions.contains(&"session-1".to_string()));
        assert!(config.sessions.contains(&"session-2".to_string()));
    }

    #[test]
    fn test_config_serialization() {
        let config = SessionConfig {
            count: 5,
            last_updated: DateTime::parse_from_rfc3339("2025-01-12T10:30:00Z")
                .unwrap()
                .with_timezone(&Utc),
            sessions: vec!["session-1".to_string(), "session-2".to_string()],
        };

        let json = serde_json::to_string(&config).unwrap();
        let deserialized: SessionConfig = serde_json::from_str(&json).unwrap();

        assert_eq!(config, deserialized);
    }

    #[test]
    fn test_read_nonexistent_config() {
        // Temporarily override the config path function for testing
        // This test would need to mock the home directory or use a different approach
        // For now, we'll test the config creation logic directly
        let config = SessionConfig::default();
        assert_eq!(config.count, 0);
        assert!(config.sessions.is_empty());
    }
}
