#!/bin/bash

# Install dependencies if not already installed
if ! python3 -c "import fastapi" 2>/dev/null; then
    echo "Installing dependencies..."
    pip install -r requirements.txt
fi

# Run the app
echo "Starting Lean on http://localhost:8000"
uvicorn main:app --reload --host 0.0.0.0 --port 8000