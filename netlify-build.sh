#!/bin/bash
set -e

echo "======================================"
echo "Installing Flutter..."
echo "======================================"

git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$HOME/flutter/bin:$PATH"

echo "======================================"
echo "Flutter version"
echo "======================================"

flutter --version

echo "======================================"
echo "Enabling Flutter Web"
echo "======================================"

flutter config --enable-web

echo "======================================"
echo "Getting dependencies"
echo "======================================"

flutter pub get

echo "======================================"
echo "Checking production configuration"
echo "======================================"

required_vars=(
  "TMDB_API_KEY"
  "GEMINI_API_KEY"
  "GEMINI_MODEL"
  "AI_PROVIDER"
  "SUPABASE_URL"
  "SUPABASE_ANON_KEY"
)

for var in "${required_vars[@]}"; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required Netlify environment variable is missing: $var"
    exit 1
  fi
done

echo "Production configuration variables are present."

echo "======================================"
echo "Building MovieGPT"
echo "======================================"

flutter build web --release \
  --dart-define="TMDB_API_KEY=${TMDB_API_KEY}" \
  --dart-define="GEMINI_API_KEY=${GEMINI_API_KEY}" \
  --dart-define="GEMINI_MODEL=${GEMINI_MODEL}" \
  --dart-define="AI_PROVIDER=${AI_PROVIDER}" \
  --dart-define="AI_BACKEND_URL=${AI_BACKEND_URL:-}" \
  --dart-define="OPENAI_API_KEY=${OPENAI_API_KEY:-}" \
  --dart-define="OPENAI_BASE_URL=${OPENAI_BASE_URL:-}" \
  --dart-define="OPENAI_MODEL=${OPENAI_MODEL:-}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"

echo "======================================"
echo "BUILD SUCCESSFUL"
echo "======================================"
