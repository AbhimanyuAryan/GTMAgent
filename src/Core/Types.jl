# Core type definitions for GTM Agent

"""
    MessageRole

Enum representing the role of a message in a conversation.
"""
@enum MessageRole begin
    USER
    ASSISTANT
    SYSTEM
    TOOL_RESULT
end

"""
    PermissionLevel

Enum for permission levels in the security model.
"""
@enum PermissionLevel begin
    ALLOW
    DENY
    ASK
end

"""
    TokenUsage

Tracks token usage for API calls.
"""
struct TokenUsage
    input_tokens::Int
    output_tokens::Int
    cache_creation_tokens::Int
    cache_read_tokens::Int
end

TokenUsage() = TokenUsage(0, 0, 0, 0)
TokenUsage(input::Int, output::Int) = TokenUsage(input, output, 0, 0)

"""
    ModelInfo

Information about an LLM model.
"""
struct ModelInfo
    id::String
    name::String
    context_window::Int
    max_output_tokens::Int
    supports_tools::Bool
    supports_streaming::Bool
end

"""
    PermissionConfig

Configuration for tool and action permissions.
"""
@kwdef struct PermissionConfig
    crm_read::PermissionLevel = ALLOW
    crm_write::PermissionLevel = ASK
    analytics_read::PermissionLevel = ALLOW
    send_email::PermissionLevel = ASK
    create_task::PermissionLevel = ASK
    update_deal::PermissionLevel = ASK
    run_playbook::PermissionLevel = ASK
    tool_permissions::Dict{String, PermissionLevel} = Dict{String, PermissionLevel}()
end

"""
    ModelConfig

Configuration for the LLM model.
"""
@kwdef struct ModelConfig
    provider::String = "anthropic"
    model::String = "claude-sonnet-4-20250514"
    temperature::Float64 = 0.7
    max_tokens::Int = 4096
end

"""
    AgentConfig

Configuration for the GTM Agent.
"""
@kwdef struct AgentConfig
    name::String = "gtm-agent"
    mode::Symbol = :primary  # :primary, :subagent, :readonly
    permissions::PermissionConfig = PermissionConfig()
    model::ModelConfig = ModelConfig()
    max_steps::Int = 50
    domain_focus::Vector{Symbol} = [:customer_success, :market_intel, :revenue_ops]
    system_prompt::String = ""
end
