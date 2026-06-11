//! rust-cli scaffold.

use anyhow::{Context, Result};
use clap::Parser;

/// A Rust CLI scaffold.
#[derive(Debug, Parser)]
#[command(version, about, long_about = None)]
struct Cli {
    /// Name to greet.
    #[arg(short, long, default_value = "world")]
    name: String,

    /// Repeat the greeting this many times.
    #[arg(short, long, default_value_t = 1)]
    count: u8,
}

fn run(cli: &Cli) -> Result<()> {
    // u8 bounds the repeat; widen + checked arithmetic if count ever goes untrusted
    for _ in 0..cli.count {
        println!("hello, {}", cli.name);
    }
    Ok(())
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    run(&cli).context("running rust-cli")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn run_with_defaults_is_ok() {
        let cli = Cli {
            name: "test".to_string(),
            count: 1,
        };
        assert!(run(&cli).is_ok());
    }

    #[test]
    fn run_with_zero_count_is_ok() {
        let cli = Cli {
            name: "test".to_string(),
            count: 0,
        };
        assert!(run(&cli).is_ok());
    }
}
