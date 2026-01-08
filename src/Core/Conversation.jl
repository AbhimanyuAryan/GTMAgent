# Conversation and Session management for GTM Agent

"""
    ConversationContext

Context maintained across conversation turns.
"""
@kwdef mutable struct ConversationContext
    current_focus::Symbol = :general
    active_customer_id::Union{String, Nothing} = nothing
    active_deal_ids::Vector{String} = String[]
    cached_data::Dict{String, Any} = Dict{String, Any}()
end

"""
    Conversation

A conversation with message history.
"""
mutable struct Conversation
    id::UUID
    messages::Vector{Message}
    pending_tool_calls::Vector{ToolCallPart}
    context::ConversationContext
    created_at::DateTime
    updated_at::DateTime
end

function Conversation()
    now_time = now(UTC)
    Conversation(
        uuid4(),
        Message[],
        ToolCallPart[],
        ConversationContext(),
        now_time,
        now_time
    )
end

"""
    add_message!(conv::Conversation, msg::Message)

Add a message to the conversation.
"""
function add_message!(conv::Conversation, msg::Message)
    push!(conv.messages, msg)
    conv.updated_at = now(UTC)

    # Track pending tool calls
    if msg.role == ASSISTANT
        tool_calls = get_tool_calls(msg)
        append!(conv.pending_tool_calls, tool_calls)
    end

    msg
end

"""
    add_tool_result!(conv::Conversation, tool_id::String, result::Any, is_error::Bool=false)

Add a tool result to the conversation.
"""
function add_tool_result!(conv::Conversation, tool_id::String, result::Any, is_error::Bool=false)
    # Remove from pending
    filter!(tc -> tc.tool_id != tool_id, conv.pending_tool_calls)

    # Add result message
    msg = Message(TOOL_RESULT, MessagePart[ToolResultPart(tool_id, result, is_error)])
    add_message!(conv, msg)
end

"""
    get_messages_for_api(conv::Conversation)

Get messages formatted for API calls.
"""
function get_messages_for_api(conv::Conversation)
    conv.messages
end

"""
    clear!(conv::Conversation)

Clear all messages from the conversation.
"""
function clear!(conv::Conversation)
    empty!(conv.messages)
    empty!(conv.pending_tool_calls)
    conv.context = ConversationContext()
    conv.updated_at = now(UTC)
end

"""
    DomainContext

Domain-specific context for GTM operations.
"""
@kwdef mutable struct DomainContext
    current_customer::Union{Any, Nothing} = nothing
    current_segment::Union{Any, Nothing} = nothing
    active_deals::Vector{Any} = Any[]
    recent_insights::Vector{Any} = Any[]
    cached_metrics::Dict{String, Any} = Dict{String, Any}()
end

"""
    Session

A complete agent session with conversation and context.
"""
mutable struct Session
    id::UUID
    created_at::DateTime
    updated_at::DateTime
    conversation::Conversation
    domain_context::DomainContext
    tool_history::Vector{Any}
    metadata::Dict{String, Any}
end

function Session()
    now_time = now(UTC)
    Session(
        uuid4(),
        now_time,
        now_time,
        Conversation(),
        DomainContext(),
        Any[],
        Dict{String, Any}()
    )
end

"""
    SessionStore

Abstract type for session persistence.
"""
abstract type SessionStore end

"""
    FileSessionStore

File-based session storage.
"""
struct FileSessionStore <: SessionStore
    base_path::String
end

function FileSessionStore()
    path = joinpath(homedir(), ".gtm-agent", "sessions")
    mkpath(path)
    FileSessionStore(path)
end

"""
    save_session(store::FileSessionStore, session::Session)

Save a session to disk.
"""
function save_session(store::FileSessionStore, session::Session)
    path = joinpath(store.base_path, "$(session.id).json")
    # Simplified serialization - in production would use proper JSON3 serialization
    open(path, "w") do io
        write(io, "{\"id\": \"$(session.id)\", \"created_at\": \"$(session.created_at)\"}")
    end
    path
end

"""
    list_sessions(store::FileSessionStore; limit::Int=20)

List recent sessions.
"""
function list_sessions(store::FileSessionStore; limit::Int=20)
    files = filter(f -> endswith(f, ".json"), readdir(store.base_path))
    sorted = sort(files, by=f -> mtime(joinpath(store.base_path, f)), rev=true)
    sorted[1:min(limit, length(sorted))]
end
