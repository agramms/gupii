#!/bin/bash
set -e

echo "🚀 Setting up Gupii development environment..."

# Install Ruby dependencies
echo "📦 Installing Ruby dependencies..."
gem install bundler
bundle install

# Initialize Rails application if needed
echo "🛠️  Setting up Rails application..."
bundle exec rails new . --force --database=postgresql --css=tailwind --javascript=importmap --skip-git

# Check if Claude Code is available on host machine
# This checks if the user has claude command available locally
if command -v claude >/dev/null 2>&1; then
    echo "🤖 Detected Claude Code on host machine, installing in container..."
    curl -fsSL https://claude.ai/install.sh | bash
    echo "✅ Claude Code installed successfully!"
else
    echo "ℹ️  Claude Code not detected on host machine, skipping installation."
    echo "   If you want to use Claude Code, install it locally first: https://claude.ai/code"
fi

echo "🎉 Development environment setup complete!"