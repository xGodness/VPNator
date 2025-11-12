#!/usr/bin/env bash

set -e

# 1. Check if nvm is installed
if ! command -v nvm &> /dev/null; then
  echo "nvm not found. Installing via Homebrew..."
  if ! command -v brew &> /dev/null; then
    echo "Homebrew not found. Please install Homebrew first."
    exit 1
  fi
  brew install nvm
  export NVM_DIR="$HOME/.nvm"
  mkdir -p "$NVM_DIR"
  source "$(brew --prefix nvm)/nvm.sh"
else
  # Load nvm if installed but not loaded
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# 2. Use nvm to select Node version
if [ -f ".nvmrc" ]; then
  NODE_VERSION=$(cat .nvmrc)
  echo "Using Node.js version from .nvmrc: $NODE_VERSION"
else
  NODE_VERSION="node"
  echo ".nvmrc not found. Using latest Node.js."
fi

if ! nvm use "$NODE_VERSION"; then
  echo "Node.js version $NODE_VERSION not installed. Installing..."
  nvm install "$NODE_VERSION"
  nvm use "$NODE_VERSION"
fi

# 3. Install npm dependencies
if [ -f "package.json" ]; then
  echo "Installing npm dependencies..."
  npm install
else
  echo "package.json not found. Skipping npm install."
fi

# 4. Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
  echo "Creating empty .env file..."
  touch .env
else
  echo ".env file already exists."
fi

# 5. Insert or update VITE_WS_URL variable in .env
if grep -q '^VITE_WS_URL=' .env; then
  # Update existing line
  sed -i '' 's/^VITE_WS_URL=.*/VITE_WS_URL=VITE_WS_URL/' .env
else
  # Append new line
  echo 'VITE_WS_URL=VITE_WS_URL' >> .env
fi

echo "Done."
