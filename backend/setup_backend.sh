#!/bin/bash

# Omoi Backend Setup Script

echo "🎙️  Setting up Omoi Backend..."

# Check if python3 is available
if ! command -v python3 &> /dev/null; then
    echo "❌ Error: python3 is not installed or not in your PATH."
    echo "Please install Python 3.10 - 3.12 (Conda recommended as per the guide)."
    exit 1
fi

echo "✅ Python found: $(python3 --version)"

# Check if we are in a virtual environment or conda environment
if [[ -z "$VIRTUAL_ENV" && -z "$CONDA_DEFAULT_ENV" ]]; then
    echo "⚠️  Warning: You are not running inside a virtual environment or Conda environment."
    echo " It is recommended to run this script inside the 'qwen3-tts' Conda environment described in the guide."
    read -p "Do you want to proceed anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "📦 Installing dependencies from requirements.txt..."
pip install -r requirements.txt

if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully!"
    
    echo "⬇️  Pre-downloading AI Models..."
    python download_models.py
    
    echo "🚀 To start the server, run: python main.py"
else
    echo "❌ Failed to install dependencies."
fi
