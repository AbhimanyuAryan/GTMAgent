# MCP Client implementation for connecting to external MCP servers
# This allows GTM Agent to use tools from Claude Code and other MCP servers

"""
    MCPClient

Client for connecting to MCP servers.
"""
mutable struct MCPClient
    server_cmd::Cmd
    process::Union{Base.Process, Nothing}
    input::Union{IO, Nothing}
    output::Union{IO, Nothing}
    capabilities::Dict{String, Any}
    tools::Vector{Dict{String, Any}}
    request_id::Int
    pending_requests::Dict{Int, Channel{Any}}
end

"""
    MCPClient(server_cmd::Cmd)

Create an MCP client for the given server command.
"""
function MCPClient(server_cmd::Cmd)
    MCPClient(
        server_cmd,
        nothing,
        nothing,
        nothing,
        Dict{String, Any}(),
        Dict{String, Any}[],
        0,
        Dict{Int, Channel{Any}}()
    )
end

"""
    MCPClient(server_path::String)

Create an MCP client for a server at the given path.
"""
function MCPClient(server_path::String)
    MCPClient(`$server_path`)
end

"""
    next_request_id!(client::MCPClient)

Generate the next request ID.
"""
function next_request_id!(client::MCPClient)
    client.request_id += 1
    client.request_id
end

"""
    connect!(client::MCPClient)

Connect to the MCP server.
"""
function connect!(client::MCPClient)
    # Start the server process
    client.process = open(client.server_cmd, "r+")
    client.input = client.process
    client.output = client.process

    # Send initialize request
    result = send_request(client, "initialize", Dict(
        "protocolVersion" => "2024-11-05",
        "capabilities" => Dict(),
        "clientInfo" => Dict(
            "name" => "gtm-agent-client",
            "version" => "0.1.0"
        )
    ))

    client.capabilities = get(result, "capabilities", Dict())

    # Send initialized notification
    send_notification(client, "initialized", Dict())

    # Discover tools
    discover_tools!(client)

    client
end

"""
    disconnect!(client::MCPClient)

Disconnect from the MCP server.
"""
function disconnect!(client::MCPClient)
    if !isnothing(client.process)
        send_request(client, "shutdown", Dict())
        close(client.process)
        client.process = nothing
        client.input = nothing
        client.output = nothing
    end
end

"""
    send_request(client::MCPClient, method::String, params::Dict)

Send a JSON-RPC request and wait for response.
"""
function send_request(client::MCPClient, method::String, params::Dict)
    id = next_request_id!(client)

    request = Dict(
        "jsonrpc" => "2.0",
        "id" => id,
        "method" => method,
        "params" => params
    )

    # Create channel for response
    response_ch = Channel{Any}(1)
    client.pending_requests[id] = response_ch

    # Send request
    json = JSON3.write(request)
    println(client.output, json)
    flush(client.output)

    # Wait for response
    response = take!(response_ch)
    delete!(client.pending_requests, id)

    if haskey(response, "error")
        error("MCP error: $(response["error"]["message"])")
    end

    get(response, "result", nothing)
end

"""
    send_notification(client::MCPClient, method::String, params::Dict)

Send a JSON-RPC notification (no response expected).
"""
function send_notification(client::MCPClient, method::String, params::Dict)
    notification = Dict(
        "jsonrpc" => "2.0",
        "method" => method,
        "params" => params
    )

    json = JSON3.write(notification)
    println(client.output, json)
    flush(client.output)
end

"""
    discover_tools!(client::MCPClient)

Discover available tools from the server.
"""
function discover_tools!(client::MCPClient)
    result = send_request(client, "tools/list", Dict())
    client.tools = get(result, "tools", Dict{String, Any}[])
    client.tools
end

"""
    list_tools(client::MCPClient)

List available tools from the server.
"""
function list_tools(client::MCPClient)
    client.tools
end

"""
    call_tool(client::MCPClient, tool_name::String, arguments::Dict)

Call a tool on the MCP server.
"""
function call_tool(client::MCPClient, tool_name::String, arguments::Dict)
    result = send_request(client, "tools/call", Dict(
        "name" => tool_name,
        "arguments" => arguments
    ))

    content = get(result, "content", [])
    is_error = get(result, "isError", false)

    # Extract text content
    output = ""
    for item in content
        if get(item, "type", "") == "text"
            output *= get(item, "text", "")
        end
    end

    (success = !is_error, output = output)
end

"""
    MCPToolWrapper

Wrapper to use MCP tools as local tools.
"""
struct MCPToolWrapper <: AbstractTool
    client::MCPClient
    tool_info::Dict{String, Any}
end

function info(wrapper::MCPToolWrapper)
    ti = wrapper.tool_info
    ToolInfo(
        id = "mcp_" * get(ti, "name", "unknown"),
        name = get(ti, "name", "unknown"),
        description = get(ti, "description", ""),
        category = :mcp,
        parameters = get(ti, "inputSchema", Dict{String, Any}()),
        required_permissions = Symbol[]
    )
end

function execute(wrapper::MCPToolWrapper, args::Dict, ctx)
    result = call_tool(wrapper.client, wrapper.tool_info["name"], args)

    if result.success
        success_result(result.output)
    else
        error_result(result.output)
    end
end

"""
    register_mcp_tools!(registry::ToolRegistry, client::MCPClient)

Register all tools from an MCP client with a tool registry.
"""
function register_mcp_tools!(registry::ToolRegistry, client::MCPClient)
    for tool_info in client.tools
        wrapper = MCPToolWrapper(client, tool_info)
        register!(registry, wrapper)
    end
    registry
end
