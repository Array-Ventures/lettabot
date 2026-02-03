#!/bin/bash
# Gmail Security Hook
# Blocks unauthorized email sending based on GMAIL_ALLOWED_RECIPIENTS

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Only check Bash commands
[[ "$TOOL_NAME" != "Bash" ]] && exit 0

# Get config from environment (set by config/io.ts)
ALLOWED_RECIPIENTS="${GMAIL_ALLOWED_RECIPIENTS:-}"
CONFIGURED_ACCOUNT="${GMAIL_ACCOUNT:-}"

# Block draft sends (bypass prevention)
if [[ "$COMMAND" =~ gog[[:space:]]+gmail[[:space:]]+drafts[[:space:]]+send ]]; then
  echo "You cannot send pre-composed drafts" >&2
  echo "Create a new email with 'gog gmail send --to <recipient>' instead" >&2
  exit 2
fi

# Check email sending
if [[ "$COMMAND" =~ gog[[:space:]]+gmail[[:space:]]+send ]]; then
  # Draft-only mode (empty allowlist)
  if [[ -z "$ALLOWED_RECIPIENTS" ]]; then
    echo "Cannot send emails autonomously" >&2
    echo "Create a draft with 'gog gmail drafts create' for the user to review and send manually" >&2
    exit 2
  fi

  # Extract --to recipient
  if [[ "$COMMAND" =~ --to[[:space:]]+([^[:space:]]+) ]]; then
    RECIPIENT="${BASH_REMATCH[1]}"
    RECIPIENT_LOWER=$(echo "$RECIPIENT" | tr '[:upper:]' '[:lower:]' | tr -d '"')

    # Check against allowlist
    ALLOWED=false
    IFS=',' read -ra RECIPIENTS <<< "$ALLOWED_RECIPIENTS"
    for ADDR in "${RECIPIENTS[@]}"; do
      ADDR_LOWER=$(echo "$ADDR" | tr '[:upper:]' '[:lower:]')

      # Exact match
      if [[ "$RECIPIENT_LOWER" == "$ADDR_LOWER" ]]; then
        ALLOWED=true
        break
      fi

      # Domain wildcard: *@company.com
      if [[ "$ADDR_LOWER" == *@* ]] && [[ "${ADDR_LOWER:0:2}" == "*@" ]]; then
        DOMAIN="${ADDR_LOWER:1}"  # Remove *
        if [[ "$RECIPIENT_LOWER" == *"$DOMAIN" ]]; then
          ALLOWED=true
          break
        fi
      fi
    done

    if [[ "$ALLOWED" != "true" ]]; then
      echo "Cannot send email to $RECIPIENT (not authorized)" >&2
      echo "Create a draft with 'gog gmail drafts create' for the user to review and send manually" >&2
      exit 2
    fi
  fi
fi

# Check account switching (prevent bypass via different Gmail account)
if [[ "$COMMAND" =~ gog[[:space:]]+gmail ]] && [[ "$COMMAND" =~ --account[[:space:]]+([^[:space:]]+) ]]; then
  if [[ -n "$CONFIGURED_ACCOUNT" ]]; then
    USED_ACCOUNT="${BASH_REMATCH[1]}"
    USED_ACCOUNT_LOWER=$(echo "$USED_ACCOUNT" | tr '[:upper:]' '[:lower:]' | tr -d '"')
    CONFIGURED_LOWER=$(echo "$CONFIGURED_ACCOUNT" | tr '[:upper:]' '[:lower:]')

    if [[ "$USED_ACCOUNT_LOWER" != "$CONFIGURED_LOWER" ]]; then
      echo "You can only use your configured Gmail account" >&2
      echo "Remove the --account flag to use the default account" >&2
      exit 2
    fi
  fi
fi

# Allow all other commands
exit 0
