#!/bin/bash

# ==============================================================================
# CLAUDE CODE - LITELLM STARTUP WITH SETTINGS-DRIVEN MODEL PRESETS
# ==============================================================================

# Resolve the project location from this script, not from the current directory.
_CLAUDE_PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Load API keys from the private file above the project directory.
if [ -f "${_CLAUDE_PROJECT_DIR}/../.env" ]; then
  source "${_CLAUDE_PROJECT_DIR}/../.env"
fi

[ -n "$ZAI_AUTH_TOKEN" ] && export ZAI_AUTH_TOKEN
[ -n "$XIAOMI_API_KEY" ] && export XIAOMI_API_KEY
[ -n "$DEEPSEEK_API_KEY" ] && export DEEPSEEK_API_KEY

export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
export DISABLE_AUTOUPDATER=1

# Model labels are intentionally controlled by ~/.claude/settings.json.
# Copy either settings.mimo.json or settings.deepseek.json there before launch.
# Unset values left behind by an older sourced version of this script.
unset ANTHROPIC_DEFAULT_OPUS_MODEL
unset ANTHROPIC_DEFAULT_SONNET_MODEL
unset ANTHROPIC_DEFAULT_HAIKU_MODEL

echo "API keys loaded:"
[ -n "$ZAI_AUTH_TOKEN" ] && echo "   - z.ai OK"
[ -n "$XIAOMI_API_KEY" ] && echo "   - Xiaomi MiMo OK"
[ -n "$DEEPSEEK_API_KEY" ] && echo "   - DeepSeek Official OK"

unalias claude 2>/dev/null
claude() {
  local claude_binary
  if ! claude_binary="$(type -P claude)"; then
    echo "Error: Claude Code was not found in PATH." >&2
    return 1
  fi

  # Direct Claude subcommands do not require the LiteLLM proxy.
  if [ "$#" -gt 0 ]; then
    "$claude_binary" "$@"
    return
  fi

  echo "Starting LiteLLM proxy..."
  pkill -f "litellm" 2>/dev/null
  litellm --config "${_CLAUDE_PROJECT_DIR}/litellm_config.yaml" --port 4000 > "${TMPDIR:-/tmp}/litellm.log" 2>&1 &
  echo "Waiting for the proxy to start..."
  sleep 4
  echo "Proxy ready. Launching Claude Code..."
  "$claude_binary"
}

alias claudeq='
  echo "Stopping LiteLLM proxy..."
  pkill -f "litellm" 2>/dev/null
  echo "Proxy stopped."
'

echo "Configured command: claude"
echo "Model preset: ~/.claude/settings.json"
echo "Use claudeq to stop the proxy after the session."
