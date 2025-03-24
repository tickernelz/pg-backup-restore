#!/bin/bash
#
# Installation script for PostgreSQL Database Backup & Restore Tool
#
# Author: Zhafron Adani Kautsar (tickernelz)
# Website: https://github.com/tickernelz
# License: MIT
#

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}PostgreSQL Database Backup & Restore Tool - Installation${NC}"
echo -e "${BLUE}${BOLD}------------------------------------------${NC}\n"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${YELLOW}Note: Running without root privileges. Installation will be local to current user.${NC}"
    INSTALL_DIR="$HOME/.local/bin"
    CONFIG_DIR="$HOME"
else
    INSTALL_DIR="/usr/local/bin"
    CONFIG_DIR="/etc"
fi

# Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Creating directory $INSTALL_DIR...${NC}"
    mkdir -p "$INSTALL_DIR"
fi

# Copy script to installation directory
echo -e "${GREEN}Installing pg_backup_restore.sh to $INSTALL_DIR...${NC}"
cp pg_backup_restore.sh "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/pg_backup_restore.sh"

# Create symlink for easier access
if [ -d "$INSTALL_DIR" ] && [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo -e "${YELLOW}Note: $INSTALL_DIR is not in your PATH. You may want to add it.${NC}"
fi

# Copy configuration file if it doesn't exist
if [ ! -f "$CONFIG_DIR/.pg_backup_restore.conf" ]; then
    echo -e "${GREEN}Installing configuration file to $CONFIG_DIR/.pg_backup_restore.conf...${NC}"
    cp pg_backup_restore.conf.example "$CONFIG_DIR/.pg_backup_restore.conf"
    chmod 600 "$CONFIG_DIR/.pg_backup_restore.conf"
else
    echo -e "${YELLOW}Configuration file already exists. Not overwriting.${NC}"
    echo -e "${YELLOW}See pg_backup_restore.conf.example for the latest configuration options.${NC}"
fi

echo -e "\n${GREEN}${BOLD}Installation completed!${NC}"
echo -e "${GREEN}You can now run the tool with: ${BOLD}pg_backup_restore.sh${NC}"
echo -e "${GREEN}or with the full path: ${BOLD}$INSTALL_DIR/pg_backup_restore.sh${NC}"
echo -e "\n${YELLOW}For usage instructions, run: ${BOLD}pg_backup_restore.sh --help${NC}"