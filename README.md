# GTM Agent

A Julia-based AI agent specialized in Go-to-Market strategy and Customer Success operations. GTM Agent works as a standalone CLI tool or as an MCP server that integrates with Claude Code.

## Features

- **Customer Success Management**: Health scoring, churn prediction, expansion identification
- **Revenue Operations**: Pipeline analysis, forecasting, velocity optimization
- **Market Intelligence**: Competitive analysis, market sizing, positioning
- **GTM Strategy**: Segmentation, pricing, channel strategy, product-market fit

## Installation

### Prerequisites

- Julia 1.9 or later
- Anthropic API key (will be prompted on first run, or set as `ANTHROPIC_API_KEY` environment variable)

### Setup

```bash
cd GTMAgent
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Usage

### Standalone CLI Mode

```bash
# Interactive REPL mode
julia --project=. bin/gtm-agent

# On first run, you'll be prompted to enter your Anthropic API key
# The key can be pasted from your clipboard

# Single prompt mode
julia --project=. bin/gtm-agent "What is the health score for customer CUST-001?"

# With options
julia --project=. bin/gtm-agent --model claude-sonnet-4-20250514 --temperature 0.5
```

### With Claude Code (MCP Integration)

GTM Agent can be used as an MCP server with Claude Code, providing GTM-specific tools directly in your Claude Code sessions.

#### Configuration

Add to your Claude Code MCP configuration (`~/.claude/claude_desktop_config.json` or settings):

```json
{
  "mcpServers": {
    "gtm-agent": {
      "command": "julia",
      "args": ["--project=/path/to/GTMAgent", "/path/to/GTMAgent/bin/gtm-mcp-server"]
    }
  }
}
```

#### Available Tools in Claude Code

Once configured, the following tools become available in Claude Code:

| Tool | Description |
|------|-------------|
| `calculate_health_score` | Calculate customer health score with engagement, sentiment, and financial metrics |
| `lookup_customer` | Look up detailed customer information including contract details and stakeholders |
| `analyze_pipeline` | Analyze sales pipeline metrics including value, velocity, and win rate |
| `analyze_competitor` | Get competitive intelligence and battle card information |
| `identify_churn_risk` | Identify customers at risk of churning |

#### Example Claude Code Prompts

```
"Use the GTM tools to analyze the health score for customer CUST-001"

"What customers are at risk of churning? Show me the top 5 by ARR."

"Analyze our sales pipeline and identify any deals at risk."

"Give me a competitive analysis of Acme Corp."
```

## CLI Commands

In interactive mode, the following commands are available:

| Command | Description |
|---------|-------------|
| `help` | Show help message |
| `exit` / `quit` | Exit the agent |
| `clear` | Clear conversation history |
| `tools` | List available tools |
| `status` | Show agent status |

## Configuration

### API Key Setup

When you run GTM Agent for the first time without the `ANTHROPIC_API_KEY` environment variable set, you'll be prompted to enter your API key:

```
╔═══════════════════════════════════════════════════════════════╗
║  Anthropic API Key Required                                   ║
╚═══════════════════════════════════════════════════════════════╝

Please enter your Anthropic API key:
(You can get one from: https://console.anthropic.com/settings/keys)

API Key: [paste your key here]
```

The key will be stored in the `ANTHROPIC_API_KEY` environment variable for the current session. To avoid being prompted on every run, set the environment variable in your shell profile:

```bash
# Add to ~/.bashrc or ~/.zshrc
export ANTHROPIC_API_KEY="your-api-key-here"
```

### Configuration Files

GTM Agent supports layered configuration (in order of precedence):

1. Command-line arguments
2. Environment variables (`GTM_AGENT_*`)
3. Project config (`./gtm-agent.yaml`)
4. User config (`~/.config/gtm-agent/config.yaml`)
5. Defaults

### Example Configuration

```yaml
# gtm-agent.yaml
agent:
  name: my-gtm-agent
  max_steps: 50
  temperature: 0.7

provider:
  default: anthropic
  anthropic:
    model: claude-sonnet-4-20250514

permissions:
  crm_read: allow
  crm_write: ask
  send_email: ask
  run_playbook: ask
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `GTM_AGENT_PROVIDER` | Default provider |
| `GTM_AGENT_MODEL` | Model to use |
| `GTM_AGENT_MAX_STEPS` | Maximum agent steps |
| `GTM_AGENT_TEMPERATURE` | Model temperature |

## Architecture

GTM Agent follows a modular architecture:

```
GTMAgent/
├── src/
│   ├── GTMAgent.jl           # Main module
│   ├── Core/                 # Agent, Message, Conversation
│   ├── Providers/            # LLM integrations (Anthropic, etc.)
│   ├── Tools/                # Tool system and built-in tools
│   ├── Domain/               # GTM domain models
│   ├── Permission/           # Security and permissions
│   ├── Config/               # Configuration management
│   ├── CLI/                  # Command-line interface
│   └── MCP/                  # Claude Code MCP integration
├── bin/
│   ├── gtm-agent             # CLI entry point
│   └── gtm-mcp-server        # MCP server entry point
├── test/                     # Test suite
└── Project.toml              # Julia package manifest
```

## Running Tests

```bash
julia --project=. test/runtests.jl
```

## Development

### Adding New Tools

Create a new tool by implementing the `AbstractTool` interface:

```julia
struct MyTool <: AbstractTool end

function info(::MyTool)
    ToolInfo(
        id = "my_tool",
        name = "my_tool_name",
        description = "What the tool does",
        category = :custom,
        parameters = ParameterSchema([
            ParameterDef("arg1", String, "Description", required=true)
        ])
    )
end

function execute(::MyTool, args::Dict, ctx::ToolContext)
    # Implementation
    success_result("output")
end
```

Then register it:

```julia
register!(registry, MyTool())
```

## License

MIT License
