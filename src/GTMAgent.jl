module GTMAgent

using HTTP
using JSON3
using YAML
using Dates
using UUIDs

# Core exports
export AbstractAgent, GTMAgentInstance, AgentConfig
export Message, MessageRole, MessagePart, TextPart, ToolCallPart, ToolResultPart
export Conversation, Session
export run_agent, chat!, stream_chat!

# Provider exports
export AbstractProvider, AnthropicProvider, complete, stream_complete

# Tool exports
export AbstractTool, ToolInfo, ToolContext, ToolResult, ToolRegistry
export register!, execute, list_tools

# Domain exports
export Customer, CustomerStage, HealthScore, Deal, DealStage

# CLI exports
export main, run_cli, run_repl

# MCP exports
export MCPServer, MCPClient, start_mcp_server
export connect!, disconnect!, call_tool

# Include core modules
include("Core/Types.jl")
include("Core/Message.jl")
include("Core/Conversation.jl")
include("Core/Agent.jl")

# Include providers
include("Providers/Provider.jl")
include("Providers/Anthropic.jl")

# Include tool system
include("Tools/Tool.jl")
include("Tools/Registry.jl")
include("Tools/BuiltinTools.jl")

# Include domain models
include("Domain/Customer.jl")
include("Domain/Market.jl")
include("Domain/Pipeline.jl")

# Include permission system
include("Permission/Inspector.jl")

# Include configuration
include("Config/Config.jl")

# Include CLI
include("CLI/CLI.jl")
include("CLI/REPL.jl")

# Include MCP support for Claude Code integration
include("MCP/Server.jl")
include("MCP/Client.jl")

end # module
