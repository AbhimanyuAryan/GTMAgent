# Message types for GTM Agent

"""
    MessagePart

Abstract type for message content parts.
"""
abstract type MessagePart end

"""
    TextPart

Text content in a message.
"""
struct TextPart <: MessagePart
    content::String
end

"""
    ReasoningPart

Reasoning/thinking content (may be hidden from user).
"""
struct ReasoningPart <: MessagePart
    content::String
    visible::Bool
end

ReasoningPart(content::String) = ReasoningPart(content, false)

"""
    ToolCallPart

A tool call request in a message.
"""
mutable struct ToolCallPart <: MessagePart
    tool_id::String
    tool_name::String
    arguments::Dict{String, Any}
    state::Symbol  # :pending, :executing, :completed, :failed
end

ToolCallPart(tool_id::String, tool_name::String, arguments::Dict{String, Any}) =
    ToolCallPart(tool_id, tool_name, arguments, :pending)

"""
    ToolResultPart

Result from a tool execution.
"""
struct ToolResultPart <: MessagePart
    tool_id::String
    result::Any
    is_error::Bool
    metadata::Dict{String, Any}
end

ToolResultPart(tool_id::String, result::Any) =
    ToolResultPart(tool_id, result, false, Dict{String, Any}())

ToolResultPart(tool_id::String, result::Any, is_error::Bool) =
    ToolResultPart(tool_id, result, is_error, Dict{String, Any}())

"""
    DataVisualizationPart

Visualization data in a message.
"""
struct DataVisualizationPart <: MessagePart
    chart_type::Symbol
    data::Any
    config::Dict{String, Any}
end

"""
    Message

A complete message in a conversation.
"""
struct Message
    id::UUID
    role::MessageRole
    parts::Vector{MessagePart}
    timestamp::DateTime
    metadata::Dict{String, Any}
end

function Message(role::MessageRole, parts::Vector{<:MessagePart})
    Message(uuid4(), role, convert(Vector{MessagePart}, parts), now(UTC), Dict{String, Any}())
end

function Message(role::MessageRole, content::String)
    Message(role, MessagePart[TextPart(content)])
end

# Convenience constructors
user_message(content::String) = Message(USER, content)
assistant_message(content::String) = Message(ASSISTANT, content)
system_message(content::String) = Message(SYSTEM, content)

"""
    get_text_content(msg::Message)

Extract all text content from a message.
"""
function get_text_content(msg::Message)::String
    parts = filter(p -> p isa TextPart, msg.parts)
    join([p.content for p in parts], "\n")
end

"""
    get_tool_calls(msg::Message)

Extract all tool calls from a message.
"""
function get_tool_calls(msg::Message)::Vector{ToolCallPart}
    collect(filter(p -> p isa ToolCallPart, msg.parts))
end

"""
    has_tool_calls(msg::Message)

Check if a message contains tool calls.
"""
function has_tool_calls(msg::Message)::Bool
    any(p -> p isa ToolCallPart, msg.parts)
end
