# fish-api-keys 🐟🔑

A lightweight API key manager for [Fish Shell](https://fishshell.com/). Switch between multiple API keys across providers (Anthropic, OpenAI, Gemini, etc.) and contexts (work, personal) with a single command.

## Features

- **Multi-provider** — Anthropic, OpenAI, Gemini, or any custom provider
- **Multi-context** — work, personal, or any custom context
- **Multiple keys per context** — label keys by project, model, etc.
- **Tab completions** — built in for commands, providers, and contexts
- **Masked output** — keys are never shown in full
- **Secure storage** — config file is `chmod 600` by default

## Install

1. Copy `api-keys.fish` to your fish config directory:

```bash
cp api-keys.fish ~/.config/fish/api-keys.fish
```

2. Source it from your `~/.config/fish/config.fish`:

```fish
source ~/.config/fish/api-keys.fish
```

3. Initialize the key store:

```bash
api init
```

4. Add your keys:

```bash
api edit
```

## Key Store Format

Keys are stored in `~/.config/fish/api-keys.conf`:

```
# provider.context.label = key
anthropic.work.default     = sk-ant-api03-YOUR-KEY-HERE
anthropic.personal.default = sk-ant-api03-YOUR-KEY-HERE
openai.work.default        = sk-YOUR-KEY-HERE
openai.personal.gpt4       = sk-YOUR-KEY-HERE
gemini.work.default        = AIzaSy-YOUR-KEY-HERE
```

The format is `provider.context.label = key`. Lines starting with `#` are comments.

## Usage

```bash
# Set a key (label defaults to "default")
api use anthropic work
api use openai personal gpt4

# See what's active
api status

# List all configured keys
api list
api list anthropic

# Clear keys from environment
api clear              # clear all
api clear anthropic    # clear one provider

# Manage config
api init               # create starter config
api edit               # open config in $EDITOR
```

## How It Works

When you run `api use <provider> <context> [label]`, it:

1. Looks up `provider.context.label` in your `api-keys.conf`
2. Sets the corresponding environment variable (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, etc.)
3. The env var name is derived from the provider: `provider` → `PROVIDER_API_KEY`

This means you can add **any provider** — `mistral`, `cohere`, `replicate` — and it just works.

## Security Notes

- `api init` creates the key store with `chmod 600` (owner read/write only)
- Keys are always masked in terminal output (`sk-ant-a...xAAA`)
- The key store file (`api-keys.conf`) is in `.gitignore` — **never commit your real keys**
- Consider adding `api-keys.conf` to your global gitignore as well

## License

MIT
