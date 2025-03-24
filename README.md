# PostgreSQL Database Backup & Restore Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-316192?logo=postgresql&logoColor=white)](https://www.postgresql.org/)

A comprehensive script to backup and restore PostgreSQL databases with a beautiful UI, progress tracking, and support for all PostgreSQL backup formats.

## Features

### Backup Features
- **Support for All PostgreSQL Backup Formats**:
  - Plain text (.sql)
  - Custom format (.dump, .backup, .bak)
  - Tar format (.tar)
  - Directory format
- **Multiple Compression Methods**:
  - gzip (default)
  - zstd (PostgreSQL 14+)
  - lz4 (PostgreSQL 14+)
  - none (no compression)
- **Adjustable Compression Ratio**: Set compression level from 0-9
- **Parallel Processing**: Utilize multiple CPU cores for faster backups
- **Schema/Data Options**: Backup only schema or only data
- **Table Exclusion**: Exclude specific tables or table data
- **Progress Tracking**: Visual progress bar with time estimation
- **Compression Statistics**: Shows compression ratio and size reduction

### Restore Features
- **Automatic Format Detection**: Detects backup format automatically
- **Force Restore Option**: Automatically drop existing database and create a new one
- **Progress Tracking**: Visual progress bar with time estimation
- **Parallel Restoration**: Utilize multiple CPU cores for faster restoration
- **Support for Compressed Files**: Automatically handles .gz, .bz2, .xz, and .zst files

### Common Features
- **Interactive Wizard Mode**: User-friendly interface for both backup and restore operations
- **Beautiful UI**: Colorful and informative terminal interface
- **Configuration File**: Save your settings for future use
- **Optimized Performance**: Efficient backup and restore processes
- **External Tool Integration**: Optional support for dialog, pv, and ncdu for enhanced functionality

## Requirements

### Required
- Linux operating system
- PostgreSQL client tools installed (`psql`, `pg_dump`, `pg_restore`)
- Bash shell

### Optional (for Enhanced Functionality)
- `dialog` - For enhanced interactive wizard mode
- `pv` - For better progress visualization
- `ncdu` - For database size visualization

The script will automatically detect if these optional tools are installed and will suggest installation commands if they're missing.

## Installation

1. Clone this repository or download the script:

```bash
git clone https://github.com/tickernelz/pg-backup-restore.git
cd pg-backup-restore
```

2. Make the script executable:

```bash
chmod +x pg_backup_restore.sh
```

3. (Optional) Copy the example configuration file:

```bash
cp pg_backup_restore.conf.example ~/.pg_backup_restore.conf
```

## Usage

### Basic Usage

#### Interactive Wizard Mode (Recommended for New Users):
```bash
./pg_backup_restore.sh
```

#### Backup a database:
```bash
./pg_backup_restore.sh backup -d mydatabase -f backup.dump
```

#### Restore a database:
```bash
./pg_backup_restore.sh restore -d mydatabase -f backup.dump
```

### Command Line Options

```
Usage:
  ./pg_backup_restore.sh [mode] [options]

Modes:
  backup                     Backup a database
  restore                    Restore a database
  wizard                     Run in interactive wizard mode
  (no mode)                  Run in interactive wizard mode

Common Options:
  -h, --help                 Show this help message
  -d, --database <name>      Database name
  -f, --file <path>          Backup file path
  -H, --host <hostname>      Database server host (default: localhost)
  -p, --port <port>          Database server port (default: 5432)
  -U, --username <username>  Database username (default: postgres)
  -P, --password <password>  Database password (will prompt if not provided)
  -s, --save-config          Save current settings to config file

Backup Options:
  -F, --format <format>      Backup format: plain, custom, tar, directory (default: custom)
  -z, --compress <method>    Compression method: gzip, zstd, lz4, none (default: gzip)
  -Z, --compress-level <n>   Compression level: 0-9 (default: 6)
  -j, --jobs <number>        Number of parallel jobs for backup (default: 2)
  -S, --schema-only          Dump only the schema, no data
  -a, --data-only            Dump only the data, no schema
  -E, --exclude-table <name> Exclude table from backup (can be used multiple times)
  -D, --exclude-data <name>  Exclude table data from backup (can be used multiple times)
  -v, --verbose              Run in verbose mode

Restore Options:
  -F, --force                Force restore (drop existing database)
  -j, --jobs <number>        Number of parallel jobs for restore (default: 2)
  -c, --clean                Clean (drop) database objects before recreating
  -v, --verbose              Run in verbose mode
```

## Examples

### Backup Examples

#### Create a custom format backup with zstd compression:
```bash
./pg_backup_restore.sh backup -d mydatabase -f backup.dump -F custom -z zstd -Z 3
```

#### Create a plain SQL backup with schema only:
```bash
./pg_backup_restore.sh backup -d mydatabase -f schema.sql -F plain -S
```

#### Create a directory format backup with parallel jobs:
```bash
./pg_backup_restore.sh backup -d mydatabase -f backup_dir -F directory -j 4
```

#### Exclude specific tables:
```bash
./pg_backup_restore.sh backup -d mydatabase -f backup.dump -E large_table1 -E large_table2
```

#### Exclude data from specific tables:
```bash
./pg_backup_restore.sh backup -d mydatabase -f backup.dump -D log_table -D audit_table
```

### Restore Examples

#### Restore a database (auto-detect format):
```bash
./pg_backup_restore.sh restore -d mydatabase -f backup.dump
```

#### Force restore (drop existing database):
```bash
./pg_backup_restore.sh restore -d mydatabase -f backup.dump -F
```

#### Restore with parallel jobs:
```bash
./pg_backup_restore.sh restore -d mydatabase -f backup.dump -j 4
```

#### Restore with different user and host:
```bash
./pg_backup_restore.sh restore -d mydatabase -f backup.dump -U dbuser -H db.example.com
```

## Using Configuration File

You can create a configuration file at `~/.pg_backup_restore.conf` to store your default settings. An example configuration file is provided in `pg_backup_restore.conf.example`.

## Wizard Mode

The wizard mode provides an interactive, user-friendly interface for both backup and restore operations. It's especially helpful for new users or those who prefer a guided approach.

### Features of Wizard Mode

- **Interactive Menus**: Easy-to-navigate menus for all operations
- **Guided Process**: Step-by-step guidance through backup and restore operations
- **Input Validation**: Prevents common errors by validating inputs
- **Enhanced UI**: Uses dialog for a better interface if installed
- **Configuration Management**: Easy saving and loading of configurations
- **Format Detection**: Automatically detects backup formats

### Using Wizard Mode

Simply run the script without any arguments:

```bash
./pg_backup_restore.sh
```

Or explicitly specify the wizard mode:

```bash
./pg_backup_restore.sh wizard
```

The wizard will guide you through the entire process, from selecting the operation (backup or restore) to configuring all necessary parameters.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Author

**Zhafron Adani Kautsar (tickernelz)**
- GitHub: [https://github.com/tickernelz](https://github.com/tickernelz)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgements

- PostgreSQL Documentation
- The PostgreSQL Global Development Group