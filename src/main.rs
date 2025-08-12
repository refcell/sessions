use anyhow::Result;
use sessions_cli::{get_config_path, read_config};
use std::env;
use std::process::Command;

fn main() -> Result<()> {
    let args: Vec<String> = env::args().collect();
    
    match args.get(1).map(String::as_str) {
        Some("start") => {
            // Run session-start binary
            Command::new("session-start").status()?;
        }
        Some("stop") => {
            // Run session-stop binary
            Command::new("session-stop").status()?;
        }
        Some("status") | Some("count") => {
            // Show current session count
            let config = read_config()?;
            println!("📊 Active sessions: {}", config.count);
        }
        Some("reset") => {
            // Reset session count
            let config_path = get_config_path()?;
            let mut config = read_config()?;
            config.count = 0;
            config.sessions.clear();
            let json = serde_json::to_string_pretty(&config)?;
            std::fs::write(config_path, json)?;
            println!("✅ Session count reset to 0");
        }
        Some("--help") | Some("-h") | None => {
            println!("sessions - Claude Code session counter");
            println!();
            println!("Usage: sessions <command>");
            println!();
            println!("Commands:");
            println!("  start   - Increment session count");
            println!("  stop    - Decrement session count");
            println!("  status  - Show current session count");
            println!("  count   - Show current session count (alias for status)");
            println!("  reset   - Reset session count to 0");
            println!("  --help  - Show this help message");
        }
        Some(cmd) => {
            eprintln!("Unknown command: {}", cmd);
            eprintln!("Run 'sessions --help' for usage information");
            std::process::exit(1);
        }
    }
    
    Ok(())
}