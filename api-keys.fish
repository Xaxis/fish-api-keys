# ============================================================
# API Key Manager for Fish Shell
# ============================================================
# Add this to your ~/.config/fish/config.fish (or source it)
#
# Keys are stored in ~/.config/fish/api_keys.conf
# Run `api init` to create a starter config.
# ============================================================

# --------------- key store helpers ---------------

set -g __api_keys_file ~/.config/fish/api-keys.conf

function __api_keys_load
    # Parses api_keys.conf and sets global variables
    # Format: PROVIDER.CONTEXT.LABEL = sk-...
    if not test -f $__api_keys_file
        return 1
    end

    # Clear old loaded keys
    set -e __api_loaded_keys

    while read -l line
        # Skip blanks and comments
        string match -qr '^\s*#' -- $line; and continue
        string match -qr '^\s*$' -- $line; and continue

        # Parse "provider.context.label = key"
        set -l parts (string match -r '^\s*(\S+)\s*=\s*(\S+)\s*$' -- $line)
        if test (count $parts) -eq 3
            set -l path $parts[2]
            set -l key  $parts[3]
            set -ga __api_loaded_keys "$path=$key"
        end
    end <$__api_keys_file
end

function __api_keys_get --argument-names path
    # Look up a key by provider.context.label
    for entry in $__api_loaded_keys
        set -l p (string match -r '^(.+)=(.+)$' -- $entry)
        if test "$p[2]" = "$path"
            echo $p[3]
            return 0
        end
    end
    return 1
end

function __api_keys_list_for --argument-names provider context
    # List all label names for a given provider.context
    for entry in $__api_loaded_keys
        set -l p (string match -r '^(.+)=(.+)$' -- $entry)
        set -l parts (string split '.' -- $p[2])
        if test (count $parts) -ge 3
            if test "$parts[1]" = "$provider" -a "$parts[2]" = "$context"
                echo $parts[3]
            end
        end
    end
end

function __api_env_var --argument-names provider
    switch $provider
        case anthropic
            echo ANTHROPIC_API_KEY
        case openai
            echo OPENAI_API_KEY
        case '*'
            # Generic fallback: PROVIDER_API_KEY
            echo (string upper $provider)_API_KEY
    end
end

function __api_mask_key --argument-names key
    if test (string length -- $key) -gt 12
        set -l prefix (string sub -l 8 -- $key)
        set -l suffix (string sub -s -4 -- $key)
        echo "$prefix...$suffix"
    else
        echo "****"
    end
end

# --------------- main command ---------------

function api -d "Manage API keys across providers and contexts"
    __api_keys_load

    if test (count $argv) -eq 0
        __api_usage
        return 1
    end

    switch $argv[1]

        # --- api use <provider> <context> [label] ---
        case use
            if test (count $argv) -lt 3
                echo "Usage: api use <provider> <context> [label]"
                echo ""
                echo "  provider : anthropic, openai, etc."
                echo "  context  : work, personal, etc."
                echo "  label    : (optional) key name — defaults to 'default'"
                return 1
            end

            set -l provider $argv[2]
            set -l context  $argv[3]
            set -l label    default
            if test (count $argv) -ge 4
                set label $argv[4]
            end

            set -l key (__api_keys_get "$provider.$context.$label")
            if test $status -ne 0
                echo "❌  No key found: $provider.$context.$label"
                echo ""
                echo "Available keys for $provider.$context:"
                set -l labels (__api_keys_list_for $provider $context)
                if test (count $labels) -eq 0
                    echo "   (none)"
                else
                    for l in $labels
                        echo "   • $l"
                    end
                end
                return 1
            end

            set -l var (__api_env_var $provider)
            set -gx $var $key
            set -gx __api_active_{$provider}_profile "$context/$label"
            set -e __api_stashed_{$provider}_key
            set -e __api_stashed_{$provider}_profile

            echo "✅  $var → $provider/$context/$label ("(__api_mask_key $key)")"

        # --- api status ---
        case status st
            echo "🔑  Active API Keys"
            echo "─────────────────────────────────"

            for provider in anthropic openai
                set -l var          (__api_env_var $provider)
                set -l profile_var  __api_active_{$provider}_profile
                set -l stash_var    __api_stashed_{$provider}_key
                set -l stash_prof   __api_stashed_{$provider}_profile

                if set -q $var
                    set -l masked  (__api_mask_key $$var)
                    set -l profile $$profile_var
                    test -z "$profile"; and set profile "unknown (set externally)"
                    printf "  %-12s %-24s %s\n" $provider $profile $masked
                else if set -q $stash_var
                    set -l masked  (__api_mask_key $$stash_var)
                    set -l profile $$stash_prof
                    printf "  %-12s %-24s %s  ← OFF (stashed)\n" $provider $profile $masked
                else
                    printf "  %-12s %s\n" $provider "(not set)"
                end
            end
            echo ""

        # --- api list [provider] ---
        case list ls
            set -l filter_provider $argv[2]

            echo "📋 Available Keys"
            echo "─────────────────────────────────"

            set -l seen_providers
            for entry in $__api_loaded_keys
                set -l p (string match -r '^(.+)=(.+)$' -- $entry)
                set -l parts (string split '.' -- $p[2])
                if test (count $parts) -ge 3
                    set -l prov $parts[1]
                    set -l ctx  $parts[2]
                    set -l lbl  $parts[3]

                    if test -n "$filter_provider" -a "$prov" != "$filter_provider"
                        continue
                    end

                    if not contains $prov $seen_providers
                        set -a seen_providers $prov
                        echo ""
                        echo "  $prov:"
                    end

                    set -l masked (__api_mask_key $p[3])
                    printf "    %-10s %-12s %s\n" $ctx $lbl $masked
                end
            end

            if test (count $seen_providers) -eq 0
                echo "  (no keys configured — run 'api init')"
            end
            echo ""

        # --- api clear [provider] ---
        case clear
            if test (count $argv) -ge 2
                set -l var (__api_env_var $argv[2])
                set -e $var
                set -e __api_active_{$argv[2]}_profile
                set -e __api_stashed_{$argv[2]}_key
                set -e __api_stashed_{$argv[2]}_profile
                echo "🗑  Cleared $var"
            else
                for provider in anthropic openai
                    set -l var (__api_env_var $provider)
                    set -e $var
                    set -e __api_active_{$provider}_profile
                    set -e __api_stashed_{$provider}_key
                    set -e __api_stashed_{$provider}_profile
                end
                echo "🗑  Cleared all API keys from environment"
            end

        # --- api init ---
        case init
            if test -f $__api_keys_file
                echo "⚠️   $__api_keys_file already exists. Edit it directly."
                echo "   To start over, delete it first."
                return 1
            end

            mkdir -p (dirname $__api_keys_file)
            echo "\
# ============================================================
# API Key Store
# ============================================================
# Format:  provider.context.label = sk-your-key-here
#
# provider : anthropic, openai  (or any custom name)
# context  : work, personal     (or any custom name)
# label    : default, project-x (or any custom name)
#
# Usage:   api use anthropic work
#          api use openai personal gpt4-project
# ============================================================

# --- Anthropic ---
# anthropic.work.default     = sk-ant-api03-WORK-KEY-HERE
# anthropic.work.project-x   = sk-ant-api03-WORK-KEY-2-HERE
# anthropic.personal.default = sk-ant-api03-PERSONAL-KEY-HERE

# --- OpenAI ---
# openai.work.default        = sk-WORK-OPENAI-KEY-HERE
# openai.personal.default    = sk-PERSONAL-OPENAI-KEY-HERE
# openai.personal.gpt4       = sk-PERSONAL-OPENAI-GPT4-KEY
" >$__api_keys_file

            chmod 600 $__api_keys_file
            echo "✅  Created $__api_keys_file (permissions: 600)"
            echo "   Edit it to add your keys, then use: api use <provider> <context> [label]"

        # --- api edit ---
        case edit
            if not test -f $__api_keys_file
                echo "No config found. Run 'api init' first."
                return 1
            end
            if set -q EDITOR
                $EDITOR $__api_keys_file
            else
                open $__api_keys_file
            end

        # --- api off <provider> ---
        case off
            if test (count $argv) -lt 2
                echo "Usage: api off <provider>"
                echo "  Toggles a provider key OFF (unsets + stashes)"
                echo "  or back ON (restores from stash)"
                return 1
            end

            set -l provider $argv[2]
            set -l var              (__api_env_var $provider)
            set -l profile_var      __api_active_{$provider}_profile
            set -l stash_var        __api_stashed_{$provider}_key
            set -l stash_profile    __api_stashed_{$provider}_profile

            if set -q $var
                # Currently ON → stash and unset
                set -g  $stash_var $$var
                if set -q $profile_var
                    set -g $stash_profile $$profile_var
                else
                    set -g $stash_profile "unknown (set externally)"
                end
                set -e $var
                set -e $profile_var
                set -l masked (__api_mask_key $$stash_var)
                echo "🔕 $provider OFF — stashed $$stash_profile ($masked)"
                echo "   Run 'api off $provider' again to restore."
            else if set -q $stash_var
                # Currently OFF with stash → restore
                set -gx $var $$stash_var
                set -gx $profile_var $$stash_profile
                set -l masked (__api_mask_key $$var)
                echo "🔔 $provider ON — restored $$stash_profile ($masked)"
                set -e $stash_var
                set -e $stash_profile
            else
                echo "ℹ️  $provider is not set and nothing is stashed."
                return 1
            end

        # --- help / unknown ---
        case help -h --help
            __api_usage

        case '*'
            echo "Unknown command: $argv[1]"
            __api_usage
            return 1
    end
end

function __api_usage
    echo "Usage: api <command> [args]"
    echo ""
    echo "Commands:"
    echo "  use <provider> <context> [label]   Set an API key"
    echo "  status                             Show active keys"
    echo "  list [provider]                    List all configured keys"
    echo "  clear [provider]                   Unset key(s) from env"
    echo "  off <provider>                     Toggle a provider key OFF (stash) / ON (restore)"
    echo "  api off anthropic                  # unset + stash; run again to restore"
    echo "  init                               Create starter config file"
    echo "  edit                               Open config in \$EDITOR"
    echo ""
    echo "Examples:"
    echo "  api use anthropic work             # activates anthropic.work.default"
    echo "  api use openai personal gpt4       # activates openai.personal.gpt4"
    echo "  api status                         # see what's active"
    echo "  api list                           # see all available keys"
end

# --- tab completions ---

complete -c api -f
complete -c api -n "not __fish_seen_subcommand_from use status st list ls clear init edit help off" \
    -a "use status list clear init edit help off"

# Provider completion for `api off`
complete -c api -n "__fish_seen_subcommand_from off" \
    -a "anthropic openai" -d "provider"

# Dynamic completions for `api use`
complete -c api -n "__fish_seen_subcommand_from use; and test (count (commandline -opc)) -eq 2" \
    -a "anthropic openai" -d "provider"

complete -c api -n "__fish_seen_subcommand_from use; and test (count (commandline -opc)) -eq 3" \
    -a "work personal" -d "context"

complete -c api -n "__fish_seen_subcommand_from clear" \
    -a "anthropic openai" -d "provider"
