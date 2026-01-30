import chalk from 'chalk';
import ora, { type Ora } from 'ora';

// Spinner instance for async operations
let spinner: Ora | null = null;

// ============ Spinners ============

export function startSpinner(text: string): Ora {
  spinner = ora({
    text,
    color: 'cyan',
  }).start();
  return spinner;
}

export function succeedSpinner(text?: string): void {
  if (spinner) {
    spinner.succeed(text);
    spinner = null;
  }
}

export function failSpinner(text?: string): void {
  if (spinner) {
    spinner.fail(text);
    spinner = null;
  }
}

export function stopSpinner(): void {
  if (spinner) {
    spinner.stop();
    spinner = null;
  }
}

// ============ Colors & Formatting ============

export const colors = {
  // Status colors
  success: chalk.green,
  error: chalk.red,
  warning: chalk.yellow,
  info: chalk.cyan,

  // Value colors
  address: chalk.magenta,
  amount: chalk.yellow,
  number: chalk.cyan,
  hash: chalk.gray,

  // Text colors
  label: chalk.gray,
  value: chalk.white,
  highlight: chalk.bold,
  dim: chalk.dim,
};

// ============ Logging ============

export function log(message: string): void {
  console.log(message);
}

export function logSuccess(message: string): void {
  console.log(colors.success('✓ ') + message);
}

export function logError(message: string): void {
  console.error(colors.error('✗ ') + message);
}

export function logWarning(message: string): void {
  console.log(colors.warning('⚠ ') + message);
}

export function logInfo(message: string): void {
  console.log(colors.info('ℹ ') + message);
}

export function logNewLine(): void {
  console.log();
}

// ============ Formatted Output ============

export function formatAddress(address: string, truncate = false): string {
  if (truncate && address.length > 12) {
    return colors.address(`${address.slice(0, 6)}...${address.slice(-4)}`);
  }
  return colors.address(address);
}

export function formatAmount(amount: string, symbol = ''): string {
  const formatted = symbol ? `${amount} ${symbol}` : amount;
  return colors.amount(formatted);
}

export function formatTxHash(hash: string, truncate = true): string {
  if (truncate && hash.length > 16) {
    return colors.hash(`${hash.slice(0, 10)}...${hash.slice(-6)}`);
  }
  return colors.hash(hash);
}

export function formatPresaleId(id: bigint | string): string {
  return colors.number(`#${id.toString()}`);
}

export function formatStatus(status: string): string {
  const statusColors: Record<string, typeof chalk> = {
    'NotCreated': chalk.gray,
    'Active': chalk.green,
    'PendingAllocation': chalk.yellow,
    'AllocationSet': chalk.cyan,
    'ReadyForDeployment': chalk.blue,
    'Claimable': chalk.magenta,
    'Failed': chalk.red,
    'Expired': chalk.red,
  };

  const colorFn = statusColors[status] || chalk.white;
  return colorFn(status);
}

// ============ Tables ============

export interface TableRow {
  label: string;
  value: string;
}

export function printTable(rows: TableRow[], title?: string): void {
  if (title) {
    console.log();
    console.log(colors.highlight(title));
    console.log(colors.dim('─'.repeat(50)));
  }

  const maxLabelLength = Math.max(...rows.map(r => r.label.length));

  for (const row of rows) {
    const paddedLabel = row.label.padEnd(maxLabelLength);
    console.log(`  ${colors.label(paddedLabel)}  ${row.value}`);
  }
}

export function printKeyValue(label: string, value: string): void {
  console.log(`  ${colors.label(label + ':')} ${value}`);
}

// ============ Boxes ============

export function printBox(title: string, content: string[]): void {
  const width = 60;
  const border = '═'.repeat(width - 2);

  console.log();
  console.log(colors.dim(`╔${border}╗`));
  console.log(colors.dim('║') + colors.highlight(` ${title}`.padEnd(width - 2)) + colors.dim('║'));
  console.log(colors.dim(`╠${border}╣`));

  for (const line of content) {
    const paddedLine = ` ${line}`.padEnd(width - 2);
    console.log(colors.dim('║') + paddedLine + colors.dim('║'));
  }

  console.log(colors.dim(`╚${border}╝`));
}

// ============ Errors ============

export function printError(error: unknown): void {
  logNewLine();

  if (error instanceof Error) {
    logError(error.message);

    if (process.env.DEBUG === 'true' && error.stack) {
      console.log();
      console.log(colors.dim(error.stack));
    }
  } else {
    logError(String(error));
  }
}

// ============ Links ============

export function formatLink(url: string, text?: string): string {
  // Terminal hyperlinks (supported in modern terminals)
  const displayText = text || url;
  return `\u001B]8;;${url}\u0007${colors.info(displayText)}\u001B]8;;\u0007`;
}

export function printTxLink(explorerUrl: string, txHash: string): void {
  const url = `${explorerUrl}/tx/${txHash}`;
  console.log(`  ${colors.label('Explorer:')} ${formatLink(url, 'View Transaction')}`);
}
