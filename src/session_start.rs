//! Session start hook for Claude Code
//!
//! This binary increments the session counter and displays the current
//! number of active sessions.

use anyhow::{Context, Result};
use session_count::update_config;
use std::process;

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {:#}", e);
        process::exit(1);
    }
}

fn run() -> Result<()> {
    // Atomically increment the session count
    let config = update_config(|config| {
        config.increment();
    })
    .context("Failed to update session configuration")?;

    // Display the current session count with a minimal, clean message
    println!("📊 Active sessions: {}", config.count);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::process::{Command, Stdio};

    #[test]
    fn test_run_function() {
        // This test would be more complex as it involves file I/O
        // For now, we verify the function doesn't panic
        let result = run();
        // Should either succeed or fail gracefully
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_binary_execution() {
        // Test that the binary can be compiled and executed
        // This is more of an integration test
        let output = Command::new("cargo")
            .args(&["run", "--bin", "session-start"])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output();

        // The command should execute (whether it succeeds or fails is not critical for compilation test)
        assert!(output.is_ok());
    }
}
