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
echo "Applying environment variables and defaults"
echo "======================================"

export GEMINI_MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"
export AI_PROVIDER="${AI_PROVIDER:-gemini}"
export TMDB_API_KEY="${TMDB_API_KEY:-}"
export GEMINI_API_KEY="${GEMINI_API_KEY:-}"
export AI_BACKEND_URL="${AI_BACKEND_URL:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-}"
export OPENAI_MODEL="${OPENAI_MODEL:-}"
export SUPABASE_URL="${SUPABASE_URL:-}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

cat << EOF > .env
TMDB_API_KEY=${TMDB_API_KEY}
GEMINI_API_KEY=${GEMINI_API_KEY}
GEMINI_MODEL=${GEMINI_MODEL}
AI_PROVIDER=${AI_PROVIDER}
AI_BACKEND_URL=${AI_BACKEND_URL}
OPENAI_API_KEY=${OPENAI_API_KEY}
OPENAI_BASE_URL=${OPENAI_BASE_URL}
OPENAI_MODEL=${OPENAI_MODEL}
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
EOF

echo "Environment file (.env) generated."

echo "======================================"
echo "Getting dependencies"
echo "======================================"

flutter pub get

echo "======================================"
echo "Checking production configuration"
echo "======================================"

if [ -z "$TMDB_API_KEY" ]; then
  echo "WARNING: TMDB_API_KEY environment variable is not set on Netlify."
else
  echo "TMDB_API_KEY is present."
fi

if [ -z "$GEMINI_API_KEY" ]; then
  echo "WARNING: GEMINI_API_KEY environment variable is not set on Netlify."
else
  echo "GEMINI_API_KEY is present."
fi

if [ -z "$SUPABASE_URL" ]; then
  echo "WARNING: SUPABASE_URL environment variable is not set on Netlify."
else
  echo "SUPABASE_URL is present."
fi

echo "======================================"
echo "Building MovieGPT Web Release"
echo "======================================"

flutter build web --release \
  --dart-define="TMDB_API_KEY=${TMDB_API_KEY}" \
  --dart-define="GEMINI_API_KEY=${GEMINI_API_KEY}" \
  --dart-define="GEMINI_MODEL=${GEMINI_MODEL}" \
  --dart-define="AI_PROVIDER=${AI_PROVIDER}" \
  --dart-define="AI_BACKEND_URL=${AI_BACKEND_URL}" \
  --dart-define="OPENAI_API_KEY=${OPENAI_API_KEY}" \
  --dart-define="OPENAI_BASE_URL=${OPENAI_BASE_URL}" \
  --dart-define="OPENAI_MODEL=${OPENAI_MODEL}" \
  --dart-define="SUPABASE_URL=${SUPABASE_URL}" \
  --dart-define="SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}"

echo "======================================"
echo "Ensuring web asset environment file exists"
echo "======================================"

mkdir -p build/web/assets
mkdir -p build/web/assets/assets
cp .env build/web/assets/.env
cp .env build/web/assets/assets/.env

echo "======================================"
echo "BUILD SUCCESSFUL"
echo "======================================"
