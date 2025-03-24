#!/bin/bash
#
# PostgreSQL Database Backup & Restore Tool
# A comprehensive script to backup and restore PostgreSQL databases
# Supports multiple backup formats and provides progress tracking
#
# Author: Zhafron Adani Kautsar (tickernelz)
# Website: https://github.com/tickernelz
# License: MIT
#

# ANSI color codes for beautiful UI
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration file path
CONFIG_FILE="$HOME/.pg_backup_restore.conf"

# Default values
DB_HOST="localhost"
DB_PORT="5432"
DB_USER="postgres"
FORCE_RESTORE=false
PARALLEL_JOBS=2
COMPRESSION_LEVEL=6
COMPRESSION_METHOD="gzip"
BACKUP_FORMAT="custom"
EXCLUDE_TABLES=""
EXCLUDE_TABLE_DATA=""
SCHEMA_ONLY=false
DATA_ONLY=false
WIZARD_MODE=false

# External tools
DIALOG_INSTALLED=false
PV_INSTALLED=false
NCDU_INSTALLED=false

# Function to display banner
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "  _____   _____   _____             _                _____           _                 "
    echo " |  __ \ / ____| |  __ \           | |              |  __ \         | |                "
    echo " | |__) | |  __  | |__) | __ _  ___| | ___   _ _ __ | |__) |___  ___| |_ ___  _ __ ___ "
    echo " |  ___/| | |_ | |  _  / / _\` |/ __| |/ / | | | '_ \|  _  // _ \/ __| __/ _ \| '__/ _ \\"
    echo " | |    | |__| | | | \ \| (_| | (__|   <| |_| | |_) | | \ \  __/\__ \ || (_) | | |  __/"
    echo " |_|     \_____| |_|  \_\\__,_|\___|_|\_\\\\__,_| .__/|_|  \_\___||___/\__\___/|_|  \___|"
    echo "                                              | |                                      "
    echo "                                              |_|                                      "
    echo -e "${NC}"
    echo -e "${CYAN}${BOLD}A comprehensive PostgreSQL database backup & restore tool${NC}"
    echo -e "${CYAN}${BOLD}--------------------------------------------------${NC}\n"
}

# Function to display help message
show_help() {
    echo -e "${YELLOW}${BOLD}Usage:${NC}"
    echo -e "  $0 [mode] [options]"
    echo
    echo -e "${YELLOW}${BOLD}Modes:${NC}"
    echo -e "  backup                     Backup a database"
    echo -e "  restore                    Restore a database"
    echo -e "  wizard                     Run in interactive wizard mode"
    echo -e "  (no mode)                  Run in interactive wizard mode"
    echo
    echo -e "${YELLOW}${BOLD}Common Options:${NC}"
    echo -e "  -h, --help                 Show this help message"
    echo -e "  -d, --database <name>      Database name"
    echo -e "  -f, --file <path>          Backup file path"
    echo -e "  -H, --host <hostname>      Database server host (default: localhost)"
    echo -e "  -p, --port <port>          Database server port (default: 5432)"
    echo -e "  -U, --username <username>  Database username (default: postgres)"
    echo -e "  -P, --password <password>  Database password (will prompt if not provided)"
    echo -e "  -s, --save-config          Save current settings to config file"
    echo
    echo -e "${YELLOW}${BOLD}Backup Options:${NC}"
    echo -e "  -F, --format <format>      Backup format: plain, custom, tar, directory (default: custom)"
    echo -e "  -z, --compress <method>    Compression method: gzip, zstd, lz4, none (default: gzip)"
    echo -e "  -Z, --compress-level <n>   Compression level: 0-9 (default: 6)"
    echo -e "  -j, --jobs <number>        Number of parallel jobs for backup (default: 2)"
    echo -e "  -S, --schema-only          Dump only the schema, no data"
    echo -e "  -a, --data-only            Dump only the data, no schema"
    echo -e "  -E, --exclude-table <name> Exclude table from backup (can be used multiple times)"
    echo -e "  -D, --exclude-data <name>  Exclude table data from backup (can be used multiple times)"
    echo -e "  -v, --verbose              Run in verbose mode"
    echo
    echo -e "${YELLOW}${BOLD}Restore Options:${NC}"
    echo -e "  -F, --force                Force restore (drop existing database)"
    echo -e "  -j, --jobs <number>        Number of parallel jobs for restore (default: 2)"
    echo -e "  -c, --clean                Clean (drop) database objects before recreating"
    echo -e "  -v, --verbose              Run in verbose mode"
    echo
    echo -e "${YELLOW}${BOLD}Examples:${NC}"
    echo -e "  $0                           Run in interactive wizard mode"
    echo -e "  $0 backup -d mydb -f mydb.dump -F custom -z zstd -Z 3"
    echo -e "  $0 backup -d mydb -f mydb.sql -F plain -S"
    echo -e "  $0 restore -d mydb -f mydb.dump -F"
    echo -e "  $0 restore -d mydb -f mydb.sql -j 4"
    echo -e "  $0 wizard                    Run in interactive wizard mode"
    echo
}

# Function to load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${CYAN}Loading configuration from $CONFIG_FILE...${NC}"
        source "$CONFIG_FILE"
    fi
}

# Function to save configuration
save_config() {
    echo -e "${CYAN}Saving configuration to $CONFIG_FILE...${NC}"
    cat > "$CONFIG_FILE" << EOF
# PostgreSQL Backup & Restore Tool Configuration
DB_HOST="$DB_HOST"
DB_PORT="$DB_PORT"
DB_USER="$DB_USER"
PARALLEL_JOBS=$PARALLEL_JOBS
COMPRESSION_LEVEL=$COMPRESSION_LEVEL
COMPRESSION_METHOD="$COMPRESSION_METHOD"
BACKUP_FORMAT="$BACKUP_FORMAT"
# Last used values
LAST_DATABASE="$DB_NAME"
LAST_BACKUP_FILE="$BACKUP_FILE"
EOF
    if [ -n "$DB_PASSWORD" ]; then
        echo "DB_PASSWORD=\"$DB_PASSWORD\"" >> "$CONFIG_FILE"
    fi
    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}Configuration saved.${NC}"
}

# Function to check if a command is installed
check_command_installed() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Function to check for external tools
check_external_tools() {
    # Check for dialog (for wizard mode)
    if check_command_installed "dialog"; then
        DIALOG_INSTALLED=true
    fi

    # Check for pv (for progress visualization)
    if check_command_installed "pv"; then
        PV_INSTALLED=true
    fi

    # Check for ncdu (for database size visualization)
    if check_command_installed "ncdu"; then
        NCDU_INSTALLED=true
    fi
}

# Function to suggest installation of external tools
suggest_external_tools() {
    local missing_tools=()

    if [ "$DIALOG_INSTALLED" = false ]; then
        missing_tools+=("dialog")
    fi

    if [ "$PV_INSTALLED" = false ]; then
        missing_tools+=("pv")
    fi

    if [ "$NCDU_INSTALLED" = false ]; then
        missing_tools+=("ncdu")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${YELLOW}${BOLD}Recommended tools not installed:${NC}"
        echo -e "${YELLOW}The following tools can enhance the functionality of this script:${NC}"

        for tool in "${missing_tools[@]}"; do
            echo -e "  - ${CYAN}$tool${NC}"
        done

        echo -e "\n${YELLOW}You can install them with:${NC}"

        # Detect package manager
        if check_command_installed "apt-get"; then
            echo -e "${GREEN}sudo apt-get install ${missing_tools[*]}${NC}"
        elif check_command_installed "yum"; then
            echo -e "${GREEN}sudo yum install ${missing_tools[*]}${NC}"
        elif check_command_installed "dnf"; then
            echo -e "${GREEN}sudo dnf install ${missing_tools[*]}${NC}"
        elif check_command_installed "pacman"; then
            echo -e "${GREEN}sudo pacman -S ${missing_tools[*]}${NC}"
        elif check_command_installed "zypper"; then
            echo -e "${GREEN}sudo zypper install ${missing_tools[*]}${NC}"
        else
            echo -e "${GREEN}Please use your system's package manager to install these tools.${NC}"
        fi

        echo -e "\n${YELLOW}Press Enter to continue without these tools...${NC}"
        read -r
    fi
}

# Function to check if PostgreSQL is installed
check_postgres_installed() {
    local missing_tools=()

    if ! check_command_installed "psql"; then
        missing_tools+=("psql")
    fi

    if ! check_command_installed "pg_dump"; then
        missing_tools+=("pg_dump")
    fi

    if ! check_command_installed "pg_restore"; then
        missing_tools+=("pg_restore")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}${BOLD}Error: Required PostgreSQL tools are not installed:${NC}"
        for tool in "${missing_tools[@]}"; do
            echo -e "  - ${RED}$tool${NC}"
        done

        echo -e "\n${YELLOW}Please install PostgreSQL client tools and try again.${NC}"

        # Detect package manager and suggest installation command
        if check_command_installed "apt-get"; then
            echo -e "${GREEN}sudo apt-get install postgresql-client${NC}"
        elif check_command_installed "yum"; then
            echo -e "${GREEN}sudo yum install postgresql${NC}"
        elif check_command_installed "dnf"; then
            echo -e "${GREEN}sudo dnf install postgresql${NC}"
        elif check_command_installed "pacman"; then
            echo -e "${GREEN}sudo pacman -S postgresql${NC}"
        elif check_command_installed "zypper"; then
            echo -e "${GREEN}sudo zypper install postgresql${NC}"
        else
            echo -e "${GREEN}Please use your system's package manager to install PostgreSQL client tools.${NC}"
        fi

        exit 1
    fi
}

# Function to check if database exists
check_database_exists() {
    local db_exists
    db_exists=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tAc "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" 2>/dev/null)
    
    if [ "$db_exists" = "1" ]; then
        return 0  # Database exists
    else
        return 1  # Database does not exist
    fi
}

# Function to detect backup format
detect_backup_format() {
    local file="$1"
    local extension="${file##*.}"
    local second_extension
    
    # Check for compressed files
    if [[ "$extension" == "gz" || "$extension" == "bz2" || "$extension" == "xz" || "$extension" == "zip" || "$extension" == "zst" ]]; then
        second_extension=$(echo "${file%.*}" | awk -F. '{print $NF}')
        extension="$second_extension.$extension"
    fi
    
    case "$extension" in
        sql|sql.gz|sql.bz2|sql.xz|sql.zip|sql.zst)
            echo "plain"
            ;;
        dump|custom|backup|bak)
            echo "custom"
            ;;
        tar|tar.gz|tgz|tar.bz2|tbz2|tar.xz|tar.zst)
            echo "tar"
            ;;
        dir|directory)
            echo "directory"
            ;;
        *)
            # Try to detect by examining file content
            if file "$file" | grep -q "PostgreSQL custom database dump"; then
                echo "custom"
            elif file "$file" | grep -q "tar archive"; then
                echo "tar"
            elif file "$file" | grep -q "ASCII text" || file "$file" | grep -q "UTF-8 text"; then
                # Check if it contains SQL commands
                if head -n 20 "$file" | grep -q "CREATE TABLE\|CREATE FUNCTION\|BEGIN\|COMMIT\|INSERT INTO"; then
                    echo "plain"
                else
                    echo "unknown"
                fi
            else
                echo "unknown"
            fi
            ;;
    esac
}

# Function to count objects in backup file
count_backup_objects() {
    local format="$1"
    local file="$2"
    local count=0
    
    case "$format" in
        custom|tar)
            count=$(pg_restore -l "$file" 2>/dev/null | grep -v "^;\\|^$\\|^#" | wc -l)
            ;;
        plain)
            # For plain SQL, count significant lines (rough estimate)
            if [[ "$file" == *.gz ]]; then
                count=$(gunzip -c "$file" | grep -E "^(CREATE|INSERT|COPY|ALTER|SET)" | wc -l)
            elif [[ "$file" == *.bz2 ]]; then
                count=$(bunzip2 -c "$file" | grep -E "^(CREATE|INSERT|COPY|ALTER|SET)" | wc -l)
            elif [[ "$file" == *.xz ]]; then
                count=$(xz -dc "$file" | grep -E "^(CREATE|INSERT|COPY|ALTER|SET)" | wc -l)
            elif [[ "$file" == *.zst ]]; then
                count=$(zstd -dc "$file" | grep -E "^(CREATE|INSERT|COPY|ALTER|SET)" | wc -l)
            else
                count=$(grep -E "^(CREATE|INSERT|COPY|ALTER|SET)" "$file" | wc -l)
            fi
            ;;
        directory)
            count=$(find "$file" -type f | wc -l)
            ;;
        *)
            count=100  # Default value for unknown formats
            ;;
    esac
    
    echo "$count"
}

# Function to create progress bar
show_progress_bar() {
    local current=$1
    local total=$2
    local percent=$((current * 100 / total))
    local completed=$((percent / 2))
    local remaining=$((50 - completed))
    
    printf "\r[%-${completed}s%-${remaining}s] %d%%" "$(printf "%0.s#" $(seq 1 $completed))" "$(printf "%0.s " $(seq 1 $remaining))" "$percent"
}

# Function to estimate database size
estimate_db_size() {
    local db_name="$1"
    local size_bytes
    
    size_bytes=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -tAc "SELECT pg_database_size('$db_name');" 2>/dev/null)
    
    if [ -z "$size_bytes" ]; then
        echo "0"
    else
        echo "$size_bytes"
    fi
}

# Function to format size
format_size() {
    local size_bytes=$1
    local size
    
    if [ "$size_bytes" -gt 1073741824 ]; then
        size=$(echo "scale=2; $size_bytes / 1073741824" | bc)
        echo "${size}GB"
    elif [ "$size_bytes" -gt 1048576 ]; then
        size=$(echo "scale=2; $size_bytes / 1048576" | bc)
        echo "${size}MB"
    elif [ "$size_bytes" -gt 1024 ]; then
        size=$(echo "scale=2; $size_bytes / 1024" | bc)
        echo "${size}KB"
    else
        echo "${size_bytes}B"
    fi
}

# Function to backup database
backup_database() {
    local format="$1"
    local file="$2"
    local start_time
    local end_time
    local duration
    local db_size_bytes
    local db_size_human
    local backup_size_bytes
    local backup_size_human
    local compression_ratio
    local backup_cmd
    local backup_args=()
    local format_flag
    
    echo -e "\n${CYAN}${BOLD}Starting database backup...${NC}"
    echo -e "${CYAN}Format: ${BOLD}$format${NC}"
    echo -e "${CYAN}File: ${BOLD}$file${NC}"
    
    # Check if database exists
    if ! check_database_exists; then
        echo -e "${RED}${BOLD}Error: Database '$DB_NAME' does not exist.${NC}"
        exit 1
    fi
    
    # Estimate database size
    echo -e "${CYAN}Estimating database size...${NC}"
    db_size_bytes=$(estimate_db_size "$DB_NAME")
    db_size_human=$(format_size "$db_size_bytes")
    echo -e "${CYAN}Database size: ${BOLD}$db_size_human${NC}"
    
    # Set format flag
    case "$format" in
        plain)
            format_flag="p"
            ;;
        custom)
            format_flag="c"
            ;;
        tar)
            format_flag="t"
            ;;
        directory)
            format_flag="d"
            ;;
        *)
            echo -e "${RED}${BOLD}Error: Invalid backup format: $format${NC}"
            exit 1
            ;;
    esac
    
    # Build backup command
    backup_args+=("-h" "$DB_HOST" "-p" "$DB_PORT" "-U" "$DB_USER" "-F" "$format_flag")
    
    # Add compression options
    if [ "$format" != "directory" ] && [ "$COMPRESSION_METHOD" != "none" ]; then
        case "$COMPRESSION_METHOD" in
            gzip)
                backup_args+=("-Z" "$COMPRESSION_LEVEL")
                ;;
            zstd)
                # Check if pg_dump supports zstd (PostgreSQL 14+)
                if PGPASSWORD="$DB_PASSWORD" pg_dump --help | grep -q -- "--compress=zstd"; then
                    backup_args+=("--compress=zstd" "--compress-level=$COMPRESSION_LEVEL")
                else
                    echo -e "${YELLOW}Warning: zstd compression not supported by this version of pg_dump. Using gzip instead.${NC}"
                    backup_args+=("-Z" "$COMPRESSION_LEVEL")
                fi
                ;;
            lz4)
                # Check if pg_dump supports lz4 (PostgreSQL 14+)
                if PGPASSWORD="$DB_PASSWORD" pg_dump --help | grep -q -- "--compress=lz4"; then
                    backup_args+=("--compress=lz4")
                else
                    echo -e "${YELLOW}Warning: lz4 compression not supported by this version of pg_dump. Using gzip instead.${NC}"
                    backup_args+=("-Z" "$COMPRESSION_LEVEL")
                fi
                ;;
            none)
                # No compression
                ;;
            *)
                echo -e "${YELLOW}Warning: Unknown compression method: $COMPRESSION_METHOD. Using gzip instead.${NC}"
                backup_args+=("-Z" "$COMPRESSION_LEVEL")
                ;;
        esac
    fi
    
    # Add parallel jobs for custom and directory formats
    if [ "$format" = "custom" ] || [ "$format" = "directory" ]; then
        backup_args+=("-j" "$PARALLEL_JOBS")
    fi
    
    # Add schema-only or data-only options
    if [ "$SCHEMA_ONLY" = true ]; then
        backup_args+=("--schema-only")
    elif [ "$DATA_ONLY" = true ]; then
        backup_args+=("--data-only")
    fi
    
    # Add exclude tables
    if [ -n "$EXCLUDE_TABLES" ]; then
        IFS=',' read -ra TABLES <<< "$EXCLUDE_TABLES"
        for table in "${TABLES[@]}"; do
            backup_args+=("--exclude-table=$table")
        done
    fi
    
    # Add exclude table data
    if [ -n "$EXCLUDE_TABLE_DATA" ]; then
        IFS=',' read -ra TABLES <<< "$EXCLUDE_TABLE_DATA"
        for table in "${TABLES[@]}"; do
            backup_args+=("--exclude-table-data=$table")
        done
    fi
    
    # Add file output
    backup_args+=("-f" "$file")
    
    # Add database name
    backup_args+=("$DB_NAME")
    
    # Start timer
    start_time=$(date +%s)
    
    # Run backup command
    echo -e "${CYAN}Starting backup with command: pg_dump ${backup_args[@]}${NC}"
    
    # Create a named pipe for progress tracking
    pipe_file=$(mktemp -u)
    mkfifo "$pipe_file"
    
    # Start pg_dump in background
    PGPASSWORD="$DB_PASSWORD" pg_dump "${backup_args[@]}" > "$pipe_file" 2>&1 &
    backup_pid=$!
    
    # Monitor progress
    processed=0
    total=$db_size_bytes
    if [ "$total" -eq 0 ]; then
        total=1000000  # Default value if we couldn't get the size
    fi
    
    while kill -0 $backup_pid 2>/dev/null; do
        # Update progress approximately
        if [ -f "$file" ]; then
            processed=$(stat -c%s "$file" 2>/dev/null || echo "0")
        elif [ -d "$file" ]; then
            processed=$(du -sb "$file" 2>/dev/null | cut -f1 || echo "0")
        fi
        
        # Adjust for compression
        if [ "$COMPRESSION_METHOD" != "none" ]; then
            processed=$((processed * 3))  # Rough estimate for compressed size
        fi
        
        if [ "$processed" -gt "$total" ]; then
            processed=$total
        fi
        
        show_progress_bar $processed $total
        sleep 1
    done
    
    # Clean up pipe
    rm -f "$pipe_file"
    
    # Check if backup completed successfully
    wait $backup_pid
    backup_status=$?
    
    if [ $backup_status -eq 0 ]; then
        show_progress_bar $total $total
        echo -e "\n${GREEN}${BOLD}Backup completed successfully!${NC}"
    else
        echo -e "\n${RED}${BOLD}Backup failed with status $backup_status.${NC}"
        exit 1
    fi
    
    # Calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    # Get backup file size
    if [ -f "$file" ]; then
        backup_size_bytes=$(stat -c%s "$file")
    elif [ -d "$file" ]; then
        backup_size_bytes=$(du -sb "$file" | cut -f1)
    else
        backup_size_bytes=0
    fi
    
    backup_size_human=$(format_size "$backup_size_bytes")
    
    # Calculate compression ratio if applicable
    if [ "$db_size_bytes" -gt 0 ] && [ "$backup_size_bytes" -gt 0 ]; then
        compression_ratio=$(echo "scale=2; $db_size_bytes / $backup_size_bytes" | bc)
        echo -e "${GREEN}${BOLD}Backup completed in ${minutes}m ${seconds}s.${NC}"
        echo -e "${GREEN}${BOLD}Original database size: ${db_size_human}${NC}"
        echo -e "${GREEN}${BOLD}Backup file size: ${backup_size_human}${NC}"
        echo -e "${GREEN}${BOLD}Compression ratio: ${compression_ratio}x${NC}"
    else
        echo -e "${GREEN}${BOLD}Backup completed in ${minutes}m ${seconds}s.${NC}"
        echo -e "${GREEN}${BOLD}Backup file size: ${backup_size_human}${NC}"
    fi
    
    echo -e "${GREEN}${BOLD}Backup saved to: ${file}${NC}"
}

# Function to restore database
restore_database() {
    local format="$1"
    local file="$2"
    local total_objects
    local start_time
    local end_time
    local duration
    
    echo -e "\n${CYAN}${BOLD}Starting database restoration...${NC}"
    echo -e "${CYAN}Format: ${BOLD}$format${NC}"
    echo -e "${CYAN}File: ${BOLD}$file${NC}"
    
    # Get total objects for progress estimation
    echo -e "${CYAN}Analyzing backup file...${NC}"
    total_objects=$(count_backup_objects "$format" "$file")
    echo -e "${CYAN}Found approximately ${BOLD}$total_objects${NC}${CYAN} objects to restore.${NC}"
    
    # Check if database exists and handle force restore
    if check_database_exists; then
        if [ "$FORCE_RESTORE" = true ]; then
            echo -e "${YELLOW}Database '$DB_NAME' already exists. Dropping it as requested...${NC}"
            PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "DROP DATABASE \"$DB_NAME\";" postgres
            if [ $? -ne 0 ]; then
                echo -e "${RED}${BOLD}Error: Failed to drop database '$DB_NAME'.${NC}"
                exit 1
            fi
            echo -e "${GREEN}Database dropped successfully.${NC}"
        else
            echo -e "${RED}${BOLD}Error: Database '$DB_NAME' already exists.${NC}"
            echo -e "${YELLOW}Use -F or --force option to drop and recreate the database.${NC}"
            exit 1
        fi
    fi
    
    # Create database if it doesn't exist
    echo -e "${CYAN}Creating database '$DB_NAME'...${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "CREATE DATABASE \"$DB_NAME\";" postgres
    if [ $? -ne 0 ]; then
        echo -e "${RED}${BOLD}Error: Failed to create database '$DB_NAME'.${NC}"
        exit 1
    fi
    
    # Start timer
    start_time=$(date +%s)
    
    # Restore based on format
    case "$format" in
        custom)
            echo -e "${CYAN}Restoring custom format backup...${NC}"
            
            # Create a named pipe for progress tracking
            pipe_file=$(mktemp -u)
            mkfifo "$pipe_file"
            
            # Start pg_restore in background
            PGPASSWORD="$DB_PASSWORD" pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -j "$PARALLEL_JOBS" "$file" > "$pipe_file" 2>&1 &
            restore_pid=$!
            
            # Monitor progress
            processed=0
            while kill -0 $restore_pid 2>/dev/null; do
                # Update progress approximately
                processed=$((processed + total_objects / 100))
                if [ $processed -gt $total_objects ]; then
                    processed=$total_objects
                fi
                show_progress_bar $processed $total_objects
                sleep 1
            done
            
            # Clean up pipe
            rm -f "$pipe_file"
            
            # Check if restore completed successfully
            wait $restore_pid
            restore_status=$?
            if [ $restore_status -eq 0 ]; then
                show_progress_bar $total_objects $total_objects
                echo -e "\n${GREEN}${BOLD}Restore completed successfully!${NC}"
            else
                echo -e "\n${RED}${BOLD}Restore failed with status $restore_status.${NC}"
                exit 1
            fi
            ;;
            
        plain)
            echo -e "${CYAN}Restoring plain SQL backup...${NC}"
            
            # Handle compressed files
            if [[ "$file" == *.gz ]]; then
                # Use pv for progress if available
                if command -v pv &> /dev/null; then
                    gunzip -c "$file" | pv -s $(stat -c%s "$file") | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1
                else
                    # Fallback to basic progress estimation
                    gunzip -c "$file" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1 &
                    restore_pid=$!
                    
                    # Monitor progress
                    processed=0
                    while kill -0 $restore_pid 2>/dev/null; do
                        processed=$((processed + total_objects / 100))
                        if [ $processed -gt $total_objects ]; then
                            processed=$total_objects
                        fi
                        show_progress_bar $processed $total_objects
                        sleep 1
                    done
                    
                    wait $restore_pid
                    restore_status=$?
                fi
            elif [[ "$file" == *.bz2 ]]; then
                if command -v pv &> /dev/null; then
                    bunzip2 -c "$file" | pv -s $(stat -c%s "$file") | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1
                else
                    bunzip2 -c "$file" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1 &
                    restore_pid=$!
                    
                    processed=0
                    while kill -0 $restore_pid 2>/dev/null; do
                        processed=$((processed + total_objects / 100))
                        if [ $processed -gt $total_objects ]; then
                            processed=$total_objects
                        fi
                        show_progress_bar $processed $total_objects
                        sleep 1
                    done
                    
                    wait $restore_pid
                    restore_status=$?
                fi
            elif [[ "$file" == *.xz ]]; then
                if command -v pv &> /dev/null; then
                    xz -dc "$file" | pv -s $(stat -c%s "$file") | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1
                else
                    xz -dc "$file" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1 &
                    restore_pid=$!
                    
                    processed=0
                    while kill -0 $restore_pid 2>/dev/null; do
                        processed=$((processed + total_objects / 100))
                        if [ $processed -gt $total_objects ]; then
                            processed=$total_objects
                        fi
                        show_progress_bar $processed $total_objects
                        sleep 1
                    done
                    
                    wait $restore_pid
                    restore_status=$?
                fi
            elif [[ "$file" == *.zst ]]; then
                if command -v pv &> /dev/null; then
                    zstd -dc "$file" | pv -s $(stat -c%s "$file") | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1
                else
                    zstd -dc "$file" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1 &
                    restore_pid=$!
                    
                    processed=0
                    while kill -0 $restore_pid 2>/dev/null; do
                        processed=$((processed + total_objects / 100))
                        if [ $processed -gt $total_objects ]; then
                            processed=$total_objects
                        fi
                        show_progress_bar $processed $total_objects
                        sleep 1
                    done
                    
                    wait $restore_pid
                    restore_status=$?
                fi
            else
                # Regular SQL file
                if command -v pv &> /dev/null; then
                    pv "$file" | PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" > /dev/null 2>&1
                else
                    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file" > /dev/null 2>&1 &
                    restore_pid=$!
                    
                    processed=0
                    while kill -0 $restore_pid 2>/dev/null; do
                        processed=$((processed + total_objects / 100))
                        if [ $processed -gt $total_objects ]; then
                            processed=$total_objects
                        fi
                        show_progress_bar $processed $total_objects
                        sleep 1
                    done
                    
                    wait $restore_pid
                    restore_status=$?
                fi
            fi
            
            if [ ${restore_status:-0} -eq 0 ]; then
                show_progress_bar $total_objects $total_objects
                echo -e "\n${GREEN}${BOLD}Restore completed successfully!${NC}"
            else
                echo -e "\n${RED}${BOLD}Restore failed with status $restore_status.${NC}"
                exit 1
            fi
            ;;
            
        tar)
            echo -e "${CYAN}Restoring tar format backup...${NC}"
            PGPASSWORD="$DB_PASSWORD" pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -j "$PARALLEL_JOBS" -F tar "$file" > /dev/null 2>&1 &
            restore_pid=$!
            
            # Monitor progress
            processed=0
            while kill -0 $restore_pid 2>/dev/null; do
                processed=$((processed + total_objects / 100))
                if [ $processed -gt $total_objects ]; then
                    processed=$total_objects
                fi
                show_progress_bar $processed $total_objects
                sleep 1
            done
            
            wait $restore_pid
            restore_status=$?
            
            if [ $restore_status -eq 0 ]; then
                show_progress_bar $total_objects $total_objects
                echo -e "\n${GREEN}${BOLD}Restore completed successfully!${NC}"
            else
                echo -e "\n${RED}${BOLD}Restore failed with status $restore_status.${NC}"
                exit 1
            fi
            ;;
            
        directory)
            echo -e "${CYAN}Restoring directory format backup...${NC}"
            PGPASSWORD="$DB_PASSWORD" pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -j "$PARALLEL_JOBS" -F directory "$file" > /dev/null 2>&1 &
            restore_pid=$!
            
            # Monitor progress
            processed=0
            while kill -0 $restore_pid 2>/dev/null; do
                processed=$((processed + total_objects / 100))
                if [ $processed -gt $total_objects ]; then
                    processed=$total_objects
                fi
                show_progress_bar $processed $total_objects
                sleep 1
            done
            
            wait $restore_pid
            restore_status=$?
            
            if [ $restore_status -eq 0 ]; then
                show_progress_bar $total_objects $total_objects
                echo -e "\n${GREEN}${BOLD}Restore completed successfully!${NC}"
            else
                echo -e "\n${RED}${BOLD}Restore failed with status $restore_status.${NC}"
                exit 1
            fi
            ;;
            
        unknown)
            echo -e "${YELLOW}${BOLD}Warning: Unknown backup format. Attempting to restore...${NC}"
            # Try pg_restore first
            PGPASSWORD="$DB_PASSWORD" pg_restore -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" "$file" > /dev/null 2>&1
            restore_status=$?
            
            # If pg_restore fails, try psql
            if [ $restore_status -ne 0 ]; then
                echo -e "${YELLOW}pg_restore failed, trying psql...${NC}"
                PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$file" > /dev/null 2>&1
                restore_status=$?
            fi
            
            if [ $restore_status -eq 0 ]; then
                echo -e "${GREEN}${BOLD}Restore completed successfully!${NC}"
            else
                echo -e "${RED}${BOLD}Restore failed with status $restore_status.${NC}"
                exit 1
            fi
            ;;
    esac
    
    # Calculate duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    minutes=$((duration / 60))
    seconds=$((duration % 60))
    
    echo -e "${GREEN}${BOLD}Restore completed in ${minutes}m ${seconds}s.${NC}"
    
    # Analyze database to update statistics
    echo -e "${CYAN}Analyzing database to update statistics...${NC}"
    PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -c "ANALYZE;" "$DB_NAME" > /dev/null 2>&1
    
    echo -e "${GREEN}${BOLD}Database '$DB_NAME' is now ready to use!${NC}"
}

# Function to parse backup mode arguments
parse_backup_args() {
    local CLEAN_OPTION=""
    local VERBOSE_MODE=false
    local SAVE_CONFIG_OPTION=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_banner
                show_help
                exit 0
                ;;
            -d|--database)
                DB_NAME="$2"
                shift 2
                ;;
            -f|--file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -H|--host)
                DB_HOST="$2"
                shift 2
                ;;
            -p|--port)
                DB_PORT="$2"
                shift 2
                ;;
            -U|--username)
                DB_USER="$2"
                shift 2
                ;;
            -P|--password)
                DB_PASSWORD="$2"
                shift 2
                ;;
            -F|--format)
                BACKUP_FORMAT="$2"
                shift 2
                ;;
            -z|--compress)
                COMPRESSION_METHOD="$2"
                shift 2
                ;;
            -Z|--compress-level)
                COMPRESSION_LEVEL="$2"
                shift 2
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -S|--schema-only)
                SCHEMA_ONLY=true
                shift
                ;;
            -a|--data-only)
                DATA_ONLY=true
                shift
                ;;
            -E|--exclude-table)
                if [ -z "$EXCLUDE_TABLES" ]; then
                    EXCLUDE_TABLES="$2"
                else
                    EXCLUDE_TABLES="$EXCLUDE_TABLES,$2"
                fi
                shift 2
                ;;
            -D|--exclude-data)
                if [ -z "$EXCLUDE_TABLE_DATA" ]; then
                    EXCLUDE_TABLE_DATA="$2"
                else
                    EXCLUDE_TABLE_DATA="$EXCLUDE_TABLE_DATA,$2"
                fi
                shift 2
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -s|--save-config)
                SAVE_CONFIG_OPTION=true
                shift
                ;;
            *)
                echo -e "${RED}${BOLD}Error: Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}${BOLD}Error: Database name is required.${NC}"
        show_help
        exit 1
    fi
    
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}${BOLD}Error: Backup file path is required.${NC}"
        show_help
        exit 1
    fi
    
    # Validate backup format
    case "$BACKUP_FORMAT" in
        plain|custom|tar|directory)
            # Valid format
            ;;
        *)
            echo -e "${RED}${BOLD}Error: Invalid backup format: $BACKUP_FORMAT${NC}"
            echo -e "${YELLOW}Valid formats are: plain, custom, tar, directory${NC}"
            exit 1
            ;;
    esac
    
    # Validate compression method
    case "$COMPRESSION_METHOD" in
        gzip|zstd|lz4|none)
            # Valid compression method
            ;;
        *)
            echo -e "${RED}${BOLD}Error: Invalid compression method: $COMPRESSION_METHOD${NC}"
            echo -e "${YELLOW}Valid methods are: gzip, zstd, lz4, none${NC}"
            exit 1
            ;;
    esac
    
    # Validate compression level
    if ! [[ "$COMPRESSION_LEVEL" =~ ^[0-9]$ ]]; then
        echo -e "${RED}${BOLD}Error: Invalid compression level: $COMPRESSION_LEVEL${NC}"
        echo -e "${YELLOW}Compression level must be a number between 0 and 9${NC}"
        exit 1
    fi
    
    # Validate schema-only and data-only options
    if [ "$SCHEMA_ONLY" = true ] && [ "$DATA_ONLY" = true ]; then
        echo -e "${RED}${BOLD}Error: Cannot use both --schema-only and --data-only options together.${NC}"
        exit 1
    fi
    
    # Prompt for password if not provided
    if [ -z "$DB_PASSWORD" ]; then
        read -s -p "Enter password for user $DB_USER: " DB_PASSWORD
        echo
    fi
    
    # Save configuration if requested
    if [ "$SAVE_CONFIG_OPTION" = true ]; then
        save_config
    fi
    
    # Run backup
    backup_database "$BACKUP_FORMAT" "$BACKUP_FILE"
}

# Function to parse restore mode arguments
parse_restore_args() {
    local CLEAN_OPTION=""
    local VERBOSE_MODE=false
    local SAVE_CONFIG_OPTION=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_banner
                show_help
                exit 0
                ;;
            -d|--database)
                DB_NAME="$2"
                shift 2
                ;;
            -f|--file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            -H|--host)
                DB_HOST="$2"
                shift 2
                ;;
            -p|--port)
                DB_PORT="$2"
                shift 2
                ;;
            -U|--username)
                DB_USER="$2"
                shift 2
                ;;
            -P|--password)
                DB_PASSWORD="$2"
                shift 2
                ;;
            -F|--force)
                FORCE_RESTORE=true
                shift
                ;;
            -j|--jobs)
                PARALLEL_JOBS="$2"
                shift 2
                ;;
            -c|--clean)
                CLEAN_OPTION="--clean"
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -s|--save-config)
                SAVE_CONFIG_OPTION=true
                shift
                ;;
            *)
                echo -e "${RED}${BOLD}Error: Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validate required parameters
    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}${BOLD}Error: Database name is required.${NC}"
        show_help
        exit 1
    fi
    
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}${BOLD}Error: Backup file path is required.${NC}"
        show_help
        exit 1
    fi
    
    # Check if backup file exists
    if [ ! -e "$BACKUP_FILE" ]; then
        echo -e "${RED}${BOLD}Error: Backup file '$BACKUP_FILE' does not exist.${NC}"
        exit 1
    fi
    
    # Prompt for password if not provided
    if [ -z "$DB_PASSWORD" ]; then
        read -s -p "Enter password for user $DB_USER: " DB_PASSWORD
        echo
    fi
    
    # Save configuration if requested
    if [ "$SAVE_CONFIG_OPTION" = true ]; then
        save_config
    fi
    
    # Detect backup format
    FORMAT=$(detect_backup_format "$BACKUP_FILE")
    
    # Restore database
    restore_database "$FORMAT" "$BACKUP_FILE"
}

# Function to run wizard mode with dialog
run_wizard_with_dialog() {
    # Main menu
    local choice
    choice=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Main Menu" \
        --menu "Choose an operation:" 15 60 4 \
        "1" "Backup a database" \
        "2" "Restore a database" \
        "3" "View configuration" \
        "4" "Exit" 2>&1 >/dev/tty)

    case $choice in
        1)
            run_backup_wizard_dialog
            ;;
        2)
            run_restore_wizard_dialog
            ;;
        3)
            view_config_dialog
            run_wizard_with_dialog
            ;;
        4|"")
            clear
            echo -e "${GREEN}Exiting. Goodbye!${NC}"
            exit 0
            ;;
    esac
}

# Function to run backup wizard with dialog
run_backup_wizard_dialog() {
    # Get database name
    DB_NAME=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Name" \
        --inputbox "Enter the name of the database to backup:" 8 60 "$DB_NAME" 2>&1 >/dev/tty)

    if [ -z "$DB_NAME" ]; then
        dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
            --title "Error" \
            --msgbox "Database name cannot be empty!" 6 60
        run_backup_wizard_dialog
        return
    fi

    # Get backup file path
    BACKUP_FILE=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Backup File" \
        --inputbox "Enter the path for the backup file:" 8 60 "$HOME/$DB_NAME.dump" 2>&1 >/dev/tty)

    if [ -z "$BACKUP_FILE" ]; then
        dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
            --title "Error" \
            --msgbox "Backup file path cannot be empty!" 6 60
        run_backup_wizard_dialog
        return
    fi

    # Get backup format
    BACKUP_FORMAT=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Backup Format" \
        --menu "Choose backup format:" 15 60 4 \
        "custom" "Custom format (recommended)" \
        "plain" "Plain SQL text" \
        "tar" "Tar archive" \
        "directory" "Directory format" 2>&1 >/dev/tty)

    if [ -z "$BACKUP_FORMAT" ]; then
        BACKUP_FORMAT="custom"
    fi

    # Get compression method
    COMPRESSION_METHOD=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Compression Method" \
        --menu "Choose compression method:" 15 60 4 \
        "gzip" "gzip (good balance)" \
        "zstd" "zstd (better compression, PostgreSQL 14+)" \
        "lz4" "lz4 (faster, PostgreSQL 14+)" \
        "none" "No compression" 2>&1 >/dev/tty)

    if [ -z "$COMPRESSION_METHOD" ]; then
        COMPRESSION_METHOD="gzip"
    fi

    # Get compression level
    COMPRESSION_LEVEL=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Compression Level" \
        --menu "Choose compression level:" 15 60 10 \
        "0" "No compression" \
        "1" "Fastest (lowest compression)" \
        "2" "Fast" \
        "3" "Fast" \
        "4" "Medium" \
        "5" "Medium" \
        "6" "Medium (default)" \
        "7" "High" \
        "8" "High" \
        "9" "Highest (slowest)" 2>&1 >/dev/tty)

    if [ -z "$COMPRESSION_LEVEL" ]; then
        COMPRESSION_LEVEL="6"
    fi

    # Get parallel jobs
    PARALLEL_JOBS=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Parallel Jobs" \
        --inputbox "Enter the number of parallel jobs:" 8 60 "$PARALLEL_JOBS" 2>&1 >/dev/tty)

    if [ -z "$PARALLEL_JOBS" ]; then
        PARALLEL_JOBS="2"
    fi

    # Get database connection details
    DB_HOST=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Host" \
        --inputbox "Enter the database host:" 8 60 "$DB_HOST" 2>&1 >/dev/tty)

    if [ -z "$DB_HOST" ]; then
        DB_HOST="localhost"
    fi

    DB_PORT=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Port" \
        --inputbox "Enter the database port:" 8 60 "$DB_PORT" 2>&1 >/dev/tty)

    if [ -z "$DB_PORT" ]; then
        DB_PORT="5432"
    fi

    DB_USER=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database User" \
        --inputbox "Enter the database user:" 8 60 "$DB_USER" 2>&1 >/dev/tty)

    if [ -z "$DB_USER" ]; then
        DB_USER="postgres"
    fi

    # Get password securely
    DB_PASSWORD=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Password" \
        --passwordbox "Enter the database password:" 8 60 2>&1 >/dev/tty)

    # Ask about schema/data options
    local schema_data_choice
    schema_data_choice=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Schema/Data Options" \
        --menu "Choose what to backup:" 15 60 3 \
        "1" "Both schema and data (default)" \
        "2" "Schema only (no data)" \
        "3" "Data only (no schema)" 2>&1 >/dev/tty)

    case $schema_data_choice in
        2)
            SCHEMA_ONLY=true
            DATA_ONLY=false
            ;;
        3)
            SCHEMA_ONLY=false
            DATA_ONLY=true
            ;;
        *)
            SCHEMA_ONLY=false
            DATA_ONLY=false
            ;;
    esac

    # Ask about saving configuration
    local save_config_choice
    save_config_choice=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Save Configuration" \
        --yesno "Do you want to save these settings for future use?" 7 60 2>&1 >/dev/tty)

    local save_config_result=$?

    # Confirm backup
    dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Confirm Backup" \
        --yesno "Ready to backup database '$DB_NAME' to '$BACKUP_FILE'.\n\nProceed with backup?" 8 60

    local confirm_result=$?

    if [ $confirm_result -eq 0 ]; then
        clear

        # Save configuration if requested
        if [ $save_config_result -eq 0 ]; then
            save_config
        fi

        # Run backup
        backup_database "$BACKUP_FORMAT" "$BACKUP_FILE"

        # Return to main menu
        echo -e "\n${YELLOW}Press Enter to return to the main menu...${NC}"
        read -r
        run_wizard_with_dialog
    else
        run_wizard_with_dialog
    fi
}

# Function to run restore wizard with dialog
run_restore_wizard_dialog() {
    # Get database name
    DB_NAME=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Name" \
        --inputbox "Enter the name of the database to restore to:" 8 60 "$DB_NAME" 2>&1 >/dev/tty)

    if [ -z "$DB_NAME" ]; then
        dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
            --title "Error" \
            --msgbox "Database name cannot be empty!" 6 60
        run_restore_wizard_dialog
        return
    fi

    # Get backup file path
    BACKUP_FILE=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Backup File" \
        --inputbox "Enter the path of the backup file to restore:" 8 60 "$BACKUP_FILE" 2>&1 >/dev/tty)

    if [ -z "$BACKUP_FILE" ]; then
        dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
            --title "Error" \
            --msgbox "Backup file path cannot be empty!" 6 60
        run_restore_wizard_dialog
        return
    fi

    # Check if file exists
    if [ ! -e "$BACKUP_FILE" ]; then
        dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
            --title "Error" \
            --msgbox "Backup file '$BACKUP_FILE' does not exist!" 6 60
        run_restore_wizard_dialog
        return
    fi

    # Get parallel jobs
    PARALLEL_JOBS=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Parallel Jobs" \
        --inputbox "Enter the number of parallel jobs:" 8 60 "$PARALLEL_JOBS" 2>&1 >/dev/tty)

    if [ -z "$PARALLEL_JOBS" ]; then
        PARALLEL_JOBS="2"
    fi

    # Get database connection details
    DB_HOST=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Host" \
        --inputbox "Enter the database host:" 8 60 "$DB_HOST" 2>&1 >/dev/tty)

    if [ -z "$DB_HOST" ]; then
        DB_HOST="localhost"
    fi

    DB_PORT=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Port" \
        --inputbox "Enter the database port:" 8 60 "$DB_PORT" 2>&1 >/dev/tty)

    if [ -z "$DB_PORT" ]; then
        DB_PORT="5432"
    fi

    DB_USER=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database User" \
        --inputbox "Enter the database user:" 8 60 "$DB_USER" 2>&1 >/dev/tty)

    if [ -z "$DB_USER" ]; then
        DB_USER="postgres"
    fi

    # Get password securely
    DB_PASSWORD=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Database Password" \
        --passwordbox "Enter the database password:" 8 60 2>&1 >/dev/tty)

    # Ask about force restore
    local force_restore_choice
    force_restore_choice=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Force Restore" \
        --yesno "Force restore? This will drop the database if it exists." 7 60 2>&1 >/dev/tty)

    if [ $? -eq 0 ]; then
        FORCE_RESTORE=true
    else
        FORCE_RESTORE=false
    fi

    # Ask about saving configuration
    local save_config_choice
    save_config_choice=$(dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Save Configuration" \
        --yesno "Do you want to save these settings for future use?" 7 60 2>&1 >/dev/tty)

    local save_config_result=$?

    # Confirm restore
    dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Confirm Restore" \
        --yesno "Ready to restore database '$DB_NAME' from '$BACKUP_FILE'.\n\nProceed with restore?" 8 60

    local confirm_result=$?

    if [ $confirm_result -eq 0 ]; then
        clear

        # Save configuration if requested
        if [ $save_config_result -eq 0 ]; then
            save_config
        fi

        # Detect backup format
        FORMAT=$(detect_backup_format "$BACKUP_FILE")

        # Run restore
        restore_database "$FORMAT" "$BACKUP_FILE"

        # Return to main menu
        echo -e "\n${YELLOW}Press Enter to return to the main menu...${NC}"
        read -r
        run_wizard_with_dialog
    else
        run_wizard_with_dialog
    fi
}

# Function to view configuration with dialog
view_config_dialog() {
    local config_text
    config_text="Database Host: $DB_HOST\n"
    config_text+="Database Port: $DB_PORT\n"
    config_text+="Database User: $DB_USER\n"
    config_text+="Parallel Jobs: $PARALLEL_JOBS\n"
    config_text+="Compression Method: $COMPRESSION_METHOD\n"
    config_text+="Compression Level: $COMPRESSION_LEVEL\n"
    config_text+="Backup Format: $BACKUP_FORMAT\n"

    if [ -n "$LAST_DATABASE" ]; then
        config_text+="\nLast Database: $LAST_DATABASE\n"
    fi

    if [ -n "$LAST_BACKUP_FILE" ]; then
        config_text+="\nLast Backup File: $LAST_BACKUP_FILE\n"
    fi

    dialog --clear --backtitle "PostgreSQL Backup & Restore Tool" \
        --title "Current Configuration" \
        --msgbox "$config_text" 15 70
}

# Function to run wizard mode with terminal UI
run_wizard_with_terminal() {
    echo -e "${CYAN}${BOLD}PostgreSQL Backup & Restore Tool - Wizard Mode${NC}"
    echo -e "${CYAN}${BOLD}------------------------------------------${NC}\n"

    echo -e "${YELLOW}${BOLD}Main Menu:${NC}"
    echo -e "  ${CYAN}1${NC}) Backup a database"
    echo -e "  ${CYAN}2${NC}) Restore a database"
    echo -e "  ${CYAN}3${NC}) View configuration"
    echo -e "  ${CYAN}4${NC}) Exit"
    echo
    read -p "Enter your choice [1-4]: " choice

    case $choice in
        1)
            run_backup_wizard_terminal
            ;;
        2)
            run_restore_wizard_terminal
            ;;
        3)
            view_config_terminal
            run_wizard_with_terminal
            ;;
        4)
            echo -e "${GREEN}Exiting. Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            sleep 1
            clear
            run_wizard_with_terminal
            ;;
    esac
}

# Function to run backup wizard with terminal UI
run_backup_wizard_terminal() {
    clear
    echo -e "${CYAN}${BOLD}Backup Wizard${NC}"
    echo -e "${CYAN}${BOLD}-------------${NC}\n"

    # Get database name
    read -p "Enter the name of the database to backup [${DB_NAME}]: " input
    if [ -n "$input" ]; then
        DB_NAME="$input"
    fi

    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Database name cannot be empty!${NC}"
        sleep 1
        run_backup_wizard_terminal
        return
    fi

    # Get backup file path
    read -p "Enter the path for the backup file [${HOME}/${DB_NAME}.dump]: " input
    if [ -n "$input" ]; then
        BACKUP_FILE="$input"
    else
        BACKUP_FILE="${HOME}/${DB_NAME}.dump"
    fi

    # Get backup format
    echo -e "\n${YELLOW}${BOLD}Backup Format:${NC}"
    echo -e "  ${CYAN}1${NC}) Custom format (recommended)"
    echo -e "  ${CYAN}2${NC}) Plain SQL text"
    echo -e "  ${CYAN}3${NC}) Tar archive"
    echo -e "  ${CYAN}4${NC}) Directory format"
    read -p "Enter your choice [1]: " format_choice

    case $format_choice in
        2)
            BACKUP_FORMAT="plain"
            ;;
        3)
            BACKUP_FORMAT="tar"
            ;;
        4)
            BACKUP_FORMAT="directory"
            ;;
        *)
            BACKUP_FORMAT="custom"
            ;;
    esac

    # Get compression method
    echo -e "\n${YELLOW}${BOLD}Compression Method:${NC}"
    echo -e "  ${CYAN}1${NC}) gzip (good balance)"
    echo -e "  ${CYAN}2${NC}) zstd (better compression, PostgreSQL 14+)"
    echo -e "  ${CYAN}3${NC}) lz4 (faster, PostgreSQL 14+)"
    echo -e "  ${CYAN}4${NC}) No compression"
    read -p "Enter your choice [1]: " compression_choice

    case $compression_choice in
        2)
            COMPRESSION_METHOD="zstd"
            ;;
        3)
            COMPRESSION_METHOD="lz4"
            ;;
        4)
            COMPRESSION_METHOD="none"
            ;;
        *)
            COMPRESSION_METHOD="gzip"
            ;;
    esac

    # Get compression level
    if [ "$COMPRESSION_METHOD" != "none" ] && [ "$COMPRESSION_METHOD" != "lz4" ]; then
        echo -e "\n${YELLOW}${BOLD}Compression Level (0-9):${NC}"
        echo -e "  0: No compression"
        echo -e "  1: Fastest (lowest compression)"
        echo -e "  6: Medium (default)"
        echo -e "  9: Highest (slowest)"
        read -p "Enter compression level [6]: " input
        if [[ "$input" =~ ^[0-9]$ ]]; then
            COMPRESSION_LEVEL="$input"
        else
            COMPRESSION_LEVEL="6"
        fi
    fi

    # Get parallel jobs
    read -p "Enter the number of parallel jobs [${PARALLEL_JOBS}]: " input
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        PARALLEL_JOBS="$input"
    fi

    # Get database connection details
    read -p "Enter the database host [${DB_HOST}]: " input
    if [ -n "$input" ]; then
        DB_HOST="$input"
    fi

    read -p "Enter the database port [${DB_PORT}]: " input
    if [ -n "$input" ]; then
        DB_PORT="$input"
    fi

    read -p "Enter the database user [${DB_USER}]: " input
    if [ -n "$input" ]; then
        DB_USER="$input"
    fi

    # Get password securely
    read -s -p "Enter the database password: " DB_PASSWORD
    echo

    # Ask about schema/data options
    echo -e "\n${YELLOW}${BOLD}Schema/Data Options:${NC}"
    echo -e "  ${CYAN}1${NC}) Both schema and data (default)"
    echo -e "  ${CYAN}2${NC}) Schema only (no data)"
    echo -e "  ${CYAN}3${NC}) Data only (no schema)"
    read -p "Enter your choice [1]: " schema_data_choice

    case $schema_data_choice in
        2)
            SCHEMA_ONLY=true
            DATA_ONLY=false
            ;;
        3)
            SCHEMA_ONLY=false
            DATA_ONLY=true
            ;;
        *)
            SCHEMA_ONLY=false
            DATA_ONLY=false
            ;;
    esac

    # Ask about saving configuration
    read -p "Do you want to save these settings for future use? (y/n) [n]: " save_config_choice
    if [[ "$save_config_choice" =~ ^[Yy]$ ]]; then
        save_config
    fi

    # Confirm backup
    echo -e "\n${YELLOW}${BOLD}Summary:${NC}"
    echo -e "  Database: ${CYAN}${DB_NAME}${NC}"
    echo -e "  Backup File: ${CYAN}${BACKUP_FILE}${NC}"
    echo -e "  Format: ${CYAN}${BACKUP_FORMAT}${NC}"
    echo -e "  Compression: ${CYAN}${COMPRESSION_METHOD} (level ${COMPRESSION_LEVEL})${NC}"
    echo -e "  Parallel Jobs: ${CYAN}${PARALLEL_JOBS}${NC}"
    echo
    read -p "Proceed with backup? (y/n) [y]: " confirm

    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        clear
        # Run backup
        backup_database "$BACKUP_FORMAT" "$BACKUP_FILE"

        # Return to main menu
        echo -e "\n${YELLOW}Press Enter to return to the main menu...${NC}"
        read -r
        clear
        run_wizard_with_terminal
    else
        clear
        run_wizard_with_terminal
    fi
}

# Function to run restore wizard with terminal UI
run_restore_wizard_terminal() {
    clear
    echo -e "${CYAN}${BOLD}Restore Wizard${NC}"
    echo -e "${CYAN}${BOLD}--------------${NC}\n"

    # Get database name
    read -p "Enter the name of the database to restore to [${DB_NAME}]: " input
    if [ -n "$input" ]; then
        DB_NAME="$input"
    fi

    if [ -z "$DB_NAME" ]; then
        echo -e "${RED}Error: Database name cannot be empty!${NC}"
        sleep 1
        run_restore_wizard_terminal
        return
    fi

    # Get backup file path
    read -p "Enter the path of the backup file to restore [${BACKUP_FILE}]: " input
    if [ -n "$input" ]; then
        BACKUP_FILE="$input"
    fi

    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Backup file path cannot be empty!${NC}"
        sleep 1
        run_restore_wizard_terminal
        return
    fi

    # Check if file exists
    if [ ! -e "$BACKUP_FILE" ]; then
        echo -e "${RED}Error: Backup file '$BACKUP_FILE' does not exist!${NC}"
        sleep 1
        run_restore_wizard_terminal
        return
    fi

    # Get parallel jobs
    read -p "Enter the number of parallel jobs [${PARALLEL_JOBS}]: " input
    if [[ "$input" =~ ^[0-9]+$ ]]; then
        PARALLEL_JOBS="$input"
    fi

    # Get database connection details
    read -p "Enter the database host [${DB_HOST}]: " input
    if [ -n "$input" ]; then
        DB_HOST="$input"
    fi

    read -p "Enter the database port [${DB_PORT}]: " input
    if [ -n "$input" ]; then
        DB_PORT="$input"
    fi

    read -p "Enter the database user [${DB_USER}]: " input
    if [ -n "$input" ]; then
        DB_USER="$input"
    fi

    # Get password securely
    read -s -p "Enter the database password: " DB_PASSWORD
    echo

    # Ask about force restore
    read -p "Force restore? This will drop the database if it exists. (y/n) [n]: " force_restore_choice
    if [[ "$force_restore_choice" =~ ^[Yy]$ ]]; then
        FORCE_RESTORE=true
    else
        FORCE_RESTORE=false
    fi

    # Ask about saving configuration
    read -p "Do you want to save these settings for future use? (y/n) [n]: " save_config_choice
    if [[ "$save_config_choice" =~ ^[Yy]$ ]]; then
        save_config
    fi

    # Detect backup format
    FORMAT=$(detect_backup_format "$BACKUP_FILE")

    # Confirm restore
    echo -e "\n${YELLOW}${BOLD}Summary:${NC}"
    echo -e "  Database: ${CYAN}${DB_NAME}${NC}"
    echo -e "  Backup File: ${CYAN}${BACKUP_FILE}${NC}"
    echo -e "  Detected Format: ${CYAN}${FORMAT}${NC}"
    echo -e "  Force Restore: ${CYAN}$([ "$FORCE_RESTORE" = true ] && echo "Yes" || echo "No")${NC}"
    echo -e "  Parallel Jobs: ${CYAN}${PARALLEL_JOBS}${NC}"
    echo
    read -p "Proceed with restore? (y/n) [y]: " confirm

    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        clear
        # Run restore
        restore_database "$FORMAT" "$BACKUP_FILE"

        # Return to main menu
        echo -e "\n${YELLOW}Press Enter to return to the main menu...${NC}"
        read -r
        clear
        run_wizard_with_terminal
    else
        clear
        run_wizard_with_terminal
    fi
}

# Function to view configuration with terminal UI
view_config_terminal() {
    clear
    echo -e "${CYAN}${BOLD}Current Configuration${NC}"
    echo -e "${CYAN}${BOLD}--------------------${NC}\n"

    echo -e "Database Host: ${CYAN}${DB_HOST}${NC}"
    echo -e "Database Port: ${CYAN}${DB_PORT}${NC}"
    echo -e "Database User: ${CYAN}${DB_USER}${NC}"
    echo -e "Parallel Jobs: ${CYAN}${PARALLEL_JOBS}${NC}"
    echo -e "Compression Method: ${CYAN}${COMPRESSION_METHOD}${NC}"
    echo -e "Compression Level: ${CYAN}${COMPRESSION_LEVEL}${NC}"
    echo -e "Backup Format: ${CYAN}${BACKUP_FORMAT}${NC}"

    if [ -n "$LAST_DATABASE" ]; then
        echo -e "\nLast Database: ${CYAN}${LAST_DATABASE}${NC}"
    fi

    if [ -n "$LAST_BACKUP_FILE" ]; then
        echo -e "Last Backup File: ${CYAN}${LAST_BACKUP_FILE}${NC}"
    fi

    echo -e "\n${YELLOW}Press Enter to return to the main menu...${NC}"
    read -r
    clear
}

# Function to run wizard mode
run_wizard_mode() {
    if [ "$DIALOG_INSTALLED" = true ]; then
        run_wizard_with_dialog
    else
        run_wizard_with_terminal
    fi
}

# Main function
main() {
    # Load configuration
    load_config

    # Check if PostgreSQL is installed
    check_postgres_installed

    # Check for external tools
    check_external_tools

    # Display banner
    show_banner

    # Check if no arguments provided - run wizard mode
    if [ $# -eq 0 ]; then
        WIZARD_MODE=true
        suggest_external_tools
        run_wizard_mode
        exit 0
    fi

    # Parse mode
    MODE="$1"
    shift

    case "$MODE" in
        backup)
            parse_backup_args "$@"
            ;;
        restore)
            parse_restore_args "$@"
            ;;
        wizard)
            WIZARD_MODE=true
            suggest_external_tools
            run_wizard_mode
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}${BOLD}Error: Unknown mode: $MODE${NC}"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"