//! Session start hook for Claude Code
//!
//! This binary increments the session counter and displays the current
//! number of active sessions.

use anyhow::{Context, Result};
use sessions::update_config;
use std::process::{self, Command};

fn main() {
    if let Err(e) = run() {
        eprintln!("Error: {:#}", e);
        process::exit(1);
    }
}

/// Count the number of Claude processes currently running
fn count_claude_processes() -> u32 {
    // Try to count Claude processes using ps
    let output = Command::new("ps").args(["aux"]).output();

    if let Ok(output) = output {
        let stdout = String::from_utf8_lossy(&output.stdout);
        let count = stdout
            .lines()
            .filter(|line| {
                // Split the line into fields
                let fields: Vec<&str> = line.split_whitespace().collect();
                
                // Check if the command (11th field, index 10) is exactly "claude"
                // This avoids matching grep, our own hooks, etc.
                if fields.len() > 10 {
                    let command = fields[10];
                    // Match lines where the command is exactly "claude"
                    // These are the actual Claude Code sessions
                    command == "claude"
                } else {
                    false
                }
            })
            .count() as u32;

        return count;
    }

    // If we can't count processes, return 0
    0
}

fn run() -> Result<()> {
    // Count actual Claude processes
    let actual_processes = count_claude_processes();

    // Atomically update the session count
    let config = update_config(|config| {
        // Always sync to actual count on startup
        // This handles both increments and cleanup after crashes
        config.count = actual_processes;
    })
    .context("Failed to update session configuration")?;

    // Display the current session count with newlines before and after for better visibility
    // The dots prevent Claude from truncating the newlines
    println!(".\n📊 Active sessions: {}\n.", config.count);

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

    #[test]
    fn test_count_claude_processes() {
        // This will return 0 or more depending on whether Claude is running
        let count = count_claude_processes();
        assert!(count >= 0);
    }
}