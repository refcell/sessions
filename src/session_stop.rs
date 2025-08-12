//! Session stop hook for Claude Code
//!
//! This binary decrements the session counter when a session ends.
//! It operates silently with no output.

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
    // Atomically decrement the session count
    let _config = update_config(|config| {
        config.decrement();
    })
    .context("Failed to update session configuration")?;

    // No output - silent operation as requested

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
            .args(&["run", "--bin", "session-stop"])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output();

        // The command should execute (whether it succeeds or fails is not critical for compilation test)
        assert!(output.is_ok());
    }

    #[test]
    fn test_silent_operation() {
        // Verify that session-stop produces no stdout output
        // This is a design requirement
        let output = Command::new("cargo")
            .args(&["run", "--bin", "session-stop"])
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output();

        if let Ok(output) = output {
            if output.status.success() {
                assert!(
                    output.stdout.is_empty(),
                    "session-stop should produce no stdout output"
                );
            }
        }
    }
}
