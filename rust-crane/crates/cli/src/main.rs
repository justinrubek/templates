use crate::commands::{Commands, HelloCommands};

mod commands;

use clap::Parser;
#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt::init();

    let args = commands::Args::parse();
    match args.command {
        Commands::Hello(hello) => {
            let cmd = hello.command;
            match cmd {
                HelloCommands::World => {
                    println!("Hello, world!");
                }
                HelloCommands::Name { name } => {
                    println!("Hello, {}!", name);
                }
            }
        }
    }

    Ok(())
}

