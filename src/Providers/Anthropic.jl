# Anthropic Claude provider implementation

"""
    AnthropicProvider

Provider for Anthropic Claude models.
"""
struct AnthropicProvider <: AbstractProvider
    api_key::String
    model::String
    base_url::String
    max_tokens::Int
    temperature::Float64
end

"""
    AnthropicProvider(; api_key, model, base_url, max_tokens, temperature)

Create an Anthropic provider with configuration.
"""
function AnthropicProvider(;
    api_key::String = get(ENV, "ANTHROPIC_API_KEY", ""),
    model::String = "claude-sonnet-4-20250514",
    base_url::String = "https://api.anthropic.com",
    max_tokens::Int = 4096,
    temperature::Float64 = 0.7
)
    AnthropicProvider(api_key, model, base_url, max_tokens, temperature)
end

"""
Convert internal Message to Anthropic API format.
"""
function message_to_anthropic(msg::Message)
    role = if msg.role == USER
        "user"
    elseif msg.role == ASSISTANT
        "assistant"
    elseif msg.role == TOOL_RESULT
        "user"  # Tool results are sent as user messages in Anthropic API
    else
        "user"
    end

    content = []

    for part in msg.parts
        if part isa TextPart
            push!(content, Dict("type" => "text", "text" => part.content))
        elseif part isa ToolCallPart
            push!(content, Dict(
                "type" => "tool_use",
                "id" => part.tool_id,
                "name" => part.tool_name,
                "input" => part.arguments
            ))
        elseif part isa ToolResultPart
            push!(content, Dict(
                "type" => "tool_result",
                "tool_use_id" => part.tool_id,
                "content" => string(part.result),
                "is_error" => part.is_error
            ))
        end
    end

    Dict("role" => role, "content" => content)
end

"""
Convert tool info to Anthropic API format.
"""
function tool_to_anthropic(tool_info)
    Dict(
        "name" => tool_info.name,
        "description" => tool_info.description,
        "input_schema" => tool_info.parameters
    )
end

"""
Parse Anthropic API response to internal Message format.
"""
function parse_anthropic_response(response_data)
    parts = MessagePart[]

    content = get(response_data, "content", [])
    for block in content
        block_type = get(block, "type", "")

        if block_type == "text"
            push!(parts, TextPart(get(block, "text", "")))
        elseif block_type == "tool_use"
            push!(parts, ToolCallPart(
                get(block, "id", ""),
                get(block, "name", ""),
                get(block, "input", Dict{String, Any}())
            ))
        end
    end

    # Create message
    msg = Message(ASSISTANT, parts)

    # Parse usage
    usage_data = get(response_data, "usage", Dict())
    usage = TokenUsage(
        get(usage_data, "input_tokens", 0),
        get(usage_data, "output_tokens", 0),
        get(usage_data, "cache_creation_input_tokens", 0),
        get(usage_data, "cache_read_input_tokens", 0)
    )

    # Parse finish reason
    stop_reason = get(response_data, "stop_reason", "end_turn")
    finish_reason = if stop_reason == "tool_use"
        :tool_use
    elseif stop_reason == "end_turn"
        :end_turn
    elseif stop_reason == "max_tokens"
        :max_tokens
    else
        :unknown
    end

    (message=msg, usage=usage, finish_reason=finish_reason)
end

"""
    complete(provider::AnthropicProvider, system_prompt, messages, tools)

Get a completion from Anthropic Claude.
"""
function complete(provider::AnthropicProvider, system_prompt::String, messages::Vector{Message}, tools::Vector)
    if isempty(provider.api_key)
        error("Anthropic API key not configured")
    end

    # Build request body
    body = Dict{String, Any}(
        "model" => provider.model,
        "max_tokens" => provider.max_tokens,
        "temperature" => provider.temperature,
        "system" => system_prompt,
        "messages" => [message_to_anthropic(m) for m in messages]
    )

    # Add tools if provided
    if !isempty(tools)
        body["tools"] = [tool_to_anthropic(t) for t in tools]
    end

    # Make API request
    headers = [
        "x-api-key" => provider.api_key,
        "anthropic-version" => "2023-06-01",
        "content-type" => "application/json"
    ]

    try
        response = HTTP.post(
            "$(provider.base_url)/v1/messages",
            headers,
            JSON3.write(body)
        )

        response_data = JSON3.read(String(response.body), Dict)
        result = parse_anthropic_response(response_data)

        result.message
    catch e
        if e isa HTTP.ExceptionRequest.StatusError
            error_body = String(e.response.body)
            @error "Anthropic API error" status=e.status body=error_body
            error("Anthropic API error: $(e.status)")
        else
            rethrow(e)
        end
    end
end

"""
    stream_complete(provider::AnthropicProvider, system_prompt, messages, tools)

Get a streaming completion from Anthropic Claude.
"""
function stream_complete(provider::AnthropicProvider, system_prompt::String, messages::Vector{Message}, tools::Vector)
    Channel{Message}(32) do ch
        if isempty(provider.api_key)
            error("Anthropic API key not configured")
        end

        # Build request body with streaming
        body = Dict{String, Any}(
            "model" => provider.model,
            "max_tokens" => provider.max_tokens,
            "temperature" => provider.temperature,
            "system" => system_prompt,
            "messages" => [message_to_anthropic(m) for m in messages],
            "stream" => true
        )

        if !isempty(tools)
            body["tools"] = [tool_to_anthropic(t) for t in tools]
        end

        headers = [
            "x-api-key" => provider.api_key,
            "anthropic-version" => "2023-06-01",
            "content-type" => "application/json"
        ]

        # For simplicity, fall back to non-streaming
        # Full streaming implementation would parse SSE events
        try
            body["stream"] = false
            response = HTTP.post(
                "$(provider.base_url)/v1/messages",
                headers,
                JSON3.write(body)
            )

            response_data = JSON3.read(String(response.body), Dict)
            result = parse_anthropic_response(response_data)
            put!(ch, result.message)
        catch e
            @error "Streaming error" exception=e
        end
    end
end

"""
    model_info(provider::AnthropicProvider)

Get information about the Anthropic model.
"""
function model_info(provider::AnthropicProvider)::ModelInfo
    # Model info based on known Claude models
    if contains(provider.model, "opus")
        ModelInfo(provider.model, "Claude Opus", 200000, 4096, true, true)
    elseif contains(provider.model, "sonnet")
        ModelInfo(provider.model, "Claude Sonnet", 200000, 4096, true, true)
    elseif contains(provider.model, "haiku")
        ModelInfo(provider.model, "Claude Haiku", 200000, 4096, true, true)
    else
        ModelInfo(provider.model, "Claude", 200000, 4096, true, true)
    end
end
