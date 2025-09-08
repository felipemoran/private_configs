#!/bin/bash

# JJ Divergent Resolver Installation Script

set -e

echo "🔧 Installing JJ Divergent Resolver..."

# Check if we're in the right directory
if [[ ! -f "jj_divergent_resolver.ts" ]]; then
    echo "❌ Error: Please run this script from the jj-divergent-resolver directory"
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Error: Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ Error: npm is not installed. Please install npm first."
    exit 1
fi

# Make scripts executable
echo "🔐 Making scripts executable..."
chmod +x jj_divergent.sh
chmod +x jj_divergent_resolver.ts

# Check if jj is available
if ! command -v jj &> /dev/null; then
    echo "⚠️  Warning: jj (Jujutsu) is not found in PATH. Please make sure it's installed."
else
    echo "✅ jj (Jujutsu) found in PATH"
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📖 Usage:"
echo "  Run from this directory: ./jj_divergent.sh"
echo "  Or create a global symlink:"
echo "    sudo ln -sf $(pwd)/jj_divergent.sh /usr/local/bin/jj-divergent"
echo "    Then run: jj-divergent"
echo ""
echo "📚 For more information, see README.md"
