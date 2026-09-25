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
echo "Applying environment defaults"
echo "======================================"

export TMDB_API_KEY="${TMDB_API_KEY:-7f4649168659e5299dca69659c748641}"
export GEMINI_API_KEY="${GEMINI_API_KEY:-AQ.Ab8RN6J6QfisGVg4zk1kJnkz5dqucYODHFzcO9jhZxD-FgPf0g}"
export GEMINI_MODEL="${GEMINI_MODEL:-gemini-3.6-flash}"
export AI_PROVIDER="${AI_PROVIDER:-gemini}"
export AI_BACKEND_URL="${AI_BACKEND_URL:-}"
export OPENAI_API_KEY="${OPENAI_API_KEY:-}"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-}"
export OPENAI_MODEL="${OPENAI_MODEL:-}"
export SUPABASE_URL="${SUPABASE_URL:-https://xctogbvzpjcnlhwwjfum.supabase.co}"
export SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-sb_publishable_9GwL9mWx9hpVWpd4EwNrZg_13hIGVwo}"

echo "======================================"
echo "Getting dependencies"
echo "======================================"

flutter pub get

echo "======================================"
echo "Building MovieGPT Web Release with --dart-define"
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
echo "Security check: Removing any raw .env from publish assets"
echo "======================================"

rm -f build/web/assets/.env
rm -f build/web/assets/assets/.env

echo "======================================"
echo "BUILD SUCCESSFUL"
echo "======================================"
