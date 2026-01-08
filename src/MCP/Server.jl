# MCP Server implementation for Claude Code integration
# This allows GTM Agent to be used as an MCP server with Claude Code

"""
    MCPServer

Model Context Protocol server for Claude Code integration.
"""
mutable struct MCPServer
    tools::Any  # ToolRegistry
    input::IO
    output::IO
    running::Bool
    request_id::Int
end

"""
    MCPServer(tools)

Create an MCP server with the given tool registry.
"""
function MCPServer(tools)
    MCPServer(tools, stdin, stdout, false, 0)
end

"""
    MCPCapabilities

Server capabilities for MCP handshake.
"""
const MCP_CAPABILITIES = Dict(
    "tools" => Dict(
        "listChanged" => true
    )
)

"""
    MCP_SERVER_INFO

Server information for MCP initialization.
"""
const MCP_SERVER_INFO = Dict(
    "name" => "gtm-agent",
    "version" => "0.1.0"
)

"""
    next_request_id!(server::MCPServer)

Generate the next request ID.
"""
function next_request_id!(server::MCPServer)
    server.request_id += 1
    server.request_id
end

"""
    send_response(server::MCPServer, id, result)

Send a JSON-RPC response.
"""
function send_response(server::MCPServer, id, result)
    response = Dict(
        "jsonrpc" => "2.0",
        "id" => id,
        "result" => result
    )
    json = JSON3.write(response)
    println(server.output, json)
    flush(server.output)
end

"""
    send_error(server::MCPServer, id, code, message)

Send a JSON-RPC error response.
"""
function send_error(server::MCPServer, id, code, message)
    response = Dict(
        "jsonrpc" => "2.0",
        "id" => id,
        "error" => Dict(
            "code" => code,
            "message" => message
        )
    )
    json = JSON3.write(response)
    println(server.output, json)
    flush(server.output)
end

"""
    handle_initialize(server::MCPServer, id, params)

Handle the initialize request.
"""
function handle_initialize(server::MCPServer, id, params)
    result = Dict(
        "protocolVersion" => "2024-11-05",
        "capabilities" => MCP_CAPABILITIES,
        "serverInfo" => MCP_SERVER_INFO
    )
    send_response(server, id, result)
end

"""
    handle_tools_list(server::MCPServer, id, params)

Handle the tools/list request.
"""
function handle_tools_list(server::MCPServer, id, params)
    tools_list = []

    if !isnothing(server.tools)
        for tool in list_tools(server.tools)
            tool_info = info(tool)
            push!(tools_list, Dict(
                "name" => tool_info.name,
                "description" => tool_info.description,
                "inputSchema" => tool_info.parameters
            ))
        end
    end

    result = Dict("tools" => tools_list)
    send_response(server, id, result)
end

"""
    handle_tools_call(server::MCPServer, id, params)

Handle the tools/call request.
"""
function handle_tools_call(server::MCPServer, id, params)
    tool_name = get(params, "name", "")
    arguments = get(params, "arguments", Dict())

    if isnothing(server.tools)
        send_error(server, id, -32603, "No tools registered")
        return
    end

    # Find tool by name
    tool = get_tool_by_name(server.tools, tool_name)

    if isnothing(tool)
        send_error(server, id, -32602, "Tool not found: $tool_name")
        return
    end

    # Create context
    ctx = (
        session_id = uuid4(),
        message_id = uuid4(),
        agent = nothing,
        abort_signal = Channel{Bool}(1),
        tool_id = "mcp-$(next_request_id!(server))"
    )

    # Execute tool
    try
        result = execute(tool, arguments, ctx)

        content = if result.success
            [Dict(
                "type" => "text",
                "text" => string(result.output)
            )]
        else
            [Dict(
                "type" => "text",
                "text" => "Error: $(result.output)"
            )]
        end

        send_response(server, id, Dict(
            "content" => content,
            "isError" => !result.success
        ))
    catch e
        send_error(server, id, -32603, "Tool execution error: $e")
    end
end

"""
    handle_request(server::MCPServer, request::Dict)

Handle an incoming JSON-RPC request.
"""
function handle_request(server::MCPServer, request::Dict)
    id = get(request, "id", nothing)
    method = get(request, "method", "")
    params = get(request, "params", Dict())

    if method == "initialize"
        handle_initialize(server, id, params)
    elseif method == "initialized"
        # Notification, no response needed
    elseif method == "tools/list"
        handle_tools_list(server, id, params)
    elseif method == "tools/call"
        handle_tools_call(server, id, params)
    elseif method == "shutdown"
        server.running = false
        send_response(server, id, Dict())
    else
        if !isnothing(id)
            send_error(server, id, -32601, "Method not found: $method")
        end
    end
end

"""
    run_server(server::MCPServer)

Run the MCP server, reading from stdin and writing to stdout.
"""
function run_server(server::MCPServer)
    server.running = true

    while server.running
        line = try
            readline(server.input)
        catch e
            if e isa EOFError
                break
            end
            rethrow(e)
        end

        if isempty(line)
            continue
        end

        try
            request = JSON3.read(line, Dict)
            handle_request(server, request)
        catch e
            @error "Failed to parse request" exception=e line=line
        end
    end
end

"""
    start_mcp_server()

Start the MCP server with default tools.
"""
function start_mcp_server()
    registry = create_default_registry()
    server = MCPServer(registry)
    run_server(server)
end
