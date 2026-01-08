# Provider interface for LLM integrations

"""
    AbstractProvider

Abstract base type for LLM providers.
"""
abstract type AbstractProvider end

"""
    CompletionRequest

Request for LLM completion.
"""
struct CompletionRequest
    system_prompt::String
    messages::Vector{Message}
    tools::Vector{Any}
    temperature::Float64
    max_tokens::Int
end

"""
    CompletionResponse

Response from LLM completion.
"""
struct CompletionResponse
    message::Message
    usage::TokenUsage
    finish_reason::Symbol
end

"""
    complete(provider::AbstractProvider, system_prompt, messages, tools)

Get a completion from the provider.
"""
function complete(provider::AbstractProvider, system_prompt::String, messages::Vector{Message}, tools::Vector)
    error("complete() not implemented for $(typeof(provider))")
end

"""
    complete(provider::AbstractProvider, request::CompletionRequest)

Get a completion from the provider using a request object.
"""
function complete(provider::AbstractProvider, request::CompletionRequest)
    complete(provider, request.system_prompt, request.messages, request.tools)
end

"""
    stream_complete(provider::AbstractProvider, system_prompt, messages, tools)

Get a streaming completion from the provider.
"""
function stream_complete(provider::AbstractProvider, system_prompt::String, messages::Vector{Message}, tools::Vector)
    Channel{Message}() do ch
        # Default implementation - just return the complete response
        response = complete(provider, system_prompt, messages, tools)
        if !isnothing(response)
            put!(ch, response)
        end
    end
end

"""
    count_tokens(provider::AbstractProvider, text::String)

Count tokens in text for this provider.
"""
function count_tokens(provider::AbstractProvider, text::String)::Int
    # Rough estimate - 4 characters per token
    div(length(text), 4)
end

"""
    model_info(provider::AbstractProvider)

Get information about the provider's model.
"""
function model_info(provider::AbstractProvider)::ModelInfo
    ModelInfo(
        "unknown",
        "Unknown Model",
        100000,
        4096,
        true,
        true
    )
end
