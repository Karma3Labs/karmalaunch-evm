#!/usr/bin/env node

import { Command } from "commander";
import {
  createPresaleCommand,
  createTokenCommand,
  createWalletCommand,
} from "./commands/index.js";
import { colors, logNewLine, logError } from "./utils/output.js";
import { NETWORKS, DEFAULT_NETWORK } from "./utils/config.js";

const VERSION = "1.0.0";

// ASCII art banner
const BANNER = `
${colors.info(" _  __                          ")}
${colors.info("| |/ /__ _ _ __ _ __ ___   __ _ ")}
${colors.info("| ' // _` | '__| '_ ` _ \\ / _` |")}
${colors.info("| . \\ (_| | |  | | | | | | (_| |")}
${colors.info("|_|\\_\\__,_|_|  |_| |_| |_|\\__,_|")}

${colors.dim("Karma Launcher Presale CLI")} ${colors.dim(`v${VERSION}`)}
`;

function main(): void {
  const program = new Command();

  program
    .name("karma")
    .description(
      "Karma Launcher Presale CLI - Interact with Karma presale contracts",
    )
    .version(VERSION, "-v, --version", "Display version number")
    .option("--debug", "Enable debug mode")
    .hook("preAction", (thisCommand) => {
      if (thisCommand.opts().debug) {
        process.env.DEBUG = "true";
      }
    });

  // Add subcommands
  program.addCommand(createPresaleCommand());
  program.addCommand(createTokenCommand());
  program.addCommand(createWalletCommand());

  // Add networks command
  program
    .command("networks")
    .description("List supported networks")
    .action(() => {
      console.log(BANNER);
      logNewLine();
      console.log(colors.highlight("Supported Networks:"));
      console.log(colors.dim("─".repeat(50)));
      logNewLine();

      for (const [key, config] of Object.entries(NETWORKS)) {
        const isDefault = key === DEFAULT_NETWORK;
        const defaultBadge = isDefault ? colors.success(" (default)") : "";

        console.log(`  ${colors.info(key)}${defaultBadge}`);
        console.log(`    ${colors.label("Name:")} ${config.name}`);
        console.log(`    ${colors.label("Chain ID:")} ${config.chain.id}`);
        console.log(`    ${colors.label("Explorer:")} ${config.explorerUrl}`);
        logNewLine();
      }
    });

  // Show banner for help
  program
    .command("info")
    .description("Show CLI information")
    .action(() => {
      console.log(BANNER);
      logNewLine();
      console.log(colors.highlight("Available Commands:"));
      console.log(colors.dim("─".repeat(50)));
      logNewLine();
      console.log(
        `  ${colors.info("presale")}     Presale management (info, contribute, withdraw, claim)`,
      );
      console.log(
        `  ${colors.info("token")}       Token operations (deploy, info)`,
      );
      console.log(
        `  ${colors.info("wallet")}      Wallet management (balance, approve, address)`,
      );
      console.log(`  ${colors.info("networks")}    List supported networks`);
      logNewLine();
      console.log(colors.highlight("Quick Start:"));
      console.log(colors.dim("─".repeat(50)));
      logNewLine();
      console.log(
        `  1. Set ${colors.warning("PRIVATE_KEY")} in your ${colors.info(".env")} file`,
      );
      console.log(
        `  2. Check your balance: ${colors.info("karma wallet balance")}`,
      );
      console.log(
        `  3. View a presale: ${colors.info("karma presale info <presaleId>")}`,
      );
      console.log(
        `  4. Contribute: ${colors.info("karma presale contribute <presaleId> <amount>")}`,
      );
      logNewLine();
      console.log(colors.highlight("Documentation:"));
      console.log(colors.dim("─".repeat(50)));
      logNewLine();
      console.log(
        `  ${colors.label("GitHub:")} https://github.com/anthropics/KarmaLauncher`,
      );
      logNewLine();
    });

  // Custom help
  program.addHelpText("beforeAll", BANNER);

  // Error handling
  program.exitOverride((err) => {
    if (
      err.code === "commander.help" ||
      err.code === "commander.helpDisplayed"
    ) {
      process.exit(0);
    }
    if (err.code === "commander.version") {
      process.exit(0);
    }
    if (err.code === "commander.unknownCommand") {
      logNewLine();
      logError(
        `Unknown command. Use ${colors.info("karma --help")} for available commands.`,
      );
      process.exit(1);
    }
    // Don't throw for expected exits
    if (err.code === "commander.executeSubCommandAsync") {
      process.exit(0);
    }
    throw err;
  });

  // Parse arguments
  try {
    program.parse(process.argv);

    // Show help if no command provided
    if (process.argv.length <= 2) {
      program.help();
    }
  } catch (error) {
    if (error instanceof Error) {
      logError(error.message);
    }
    process.exit(1);
  }
}

main();
