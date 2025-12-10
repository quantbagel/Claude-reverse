#!/bin/bash
# setup-embeddings.sh - Install dependencies for semantic search
#
# This script helps you set up the embedding backend for function similarity search.
# You can choose between different backends based on your needs:
#
# 1. sentence-transformers: Best quality, runs locally, ~400MB download
# 2. TF-IDF (scikit-learn): Lightweight fallback, good enough for most cases
# 3. OpenAI API: Cloud-based, requires API key

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Semantic Search Setup ==="
echo ""
echo "This tool enables finding similar functions to help with decompilation."
echo "You need to install one of the following backends:"
echo ""
echo "1. sentence-transformers (Recommended)"
echo "   - Best quality embeddings"
echo "   - Runs locally (no API key needed)"
echo "   - Requires ~400MB model download"
echo "   - Install: pip install sentence-transformers"
echo ""
echo "2. scikit-learn (Lightweight)"
echo "   - TF-IDF based embeddings"
echo "   - Smaller install (~50MB)"
echo "   - Good enough for many cases"
echo "   - Install: pip install scikit-learn numpy"
echo ""
echo "3. OpenAI API (Cloud)"
echo "   - Requires OPENAI_API_KEY environment variable"
echo "   - Costs money (but very cheap)"
echo "   - Install: pip install openai numpy"
echo ""

# Check what's already installed
HAS_TRANSFORMERS=false
HAS_SKLEARN=false
HAS_OPENAI=false

if python3 -c "import sentence_transformers" 2>/dev/null; then
    HAS_TRANSFORMERS=true
    echo "✓ sentence-transformers is already installed"
fi

if python3 -c "import sklearn" 2>/dev/null; then
    HAS_SKLEARN=true
    echo "✓ scikit-learn is already installed"
fi

if python3 -c "import openai" 2>/dev/null; then
    HAS_OPENAI=true
    echo "✓ openai is already installed"
fi

echo ""

if $HAS_TRANSFORMERS || $HAS_SKLEARN || $HAS_OPENAI; then
    echo "You already have at least one backend installed!"
    echo ""
    read -p "Install sentence-transformers anyway? (recommended) [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Installing sentence-transformers..."
        pip3 install sentence-transformers
    else
        echo "Skipping installation."
    fi
else
    echo "No backends found. Installing sentence-transformers (recommended)..."
    echo ""
    read -p "Continue? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        pip3 install sentence-transformers numpy
        echo ""
        echo "✓ Installation complete!"
    else
        echo ""
        echo "Installation cancelled."
        echo "You can manually install later with:"
        echo "  pip3 install sentence-transformers"
        echo "or"
        echo "  pip3 install scikit-learn numpy"
    fi
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Initialize your binary (if not done already):"
echo "   ./init.sh /path/to/binary"
echo ""
echo "2. Build the semantic index:"
echo "   ./tools/index-functions"
echo ""
echo "3. Find similar functions:"
echo "   ./tools/find-similar <function_name>"
echo ""
echo "4. Run the decompilation driver:"
echo "   ./driver.sh"
echo ""
echo "The driver will now automatically use semantic search to find"
echo "similar already-decompiled functions as examples!"
echo ""
