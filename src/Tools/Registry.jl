# Tool registry for GTM Agent

"""
    ToolRegistry

Registry for managing available tools.
"""
mutable struct ToolRegistry
    tools::Dict{String, AbstractTool}
    categories::Dict{Symbol, Vector{String}}
    enabled::Set{String}
end

"""
    ToolRegistry()

Create an empty tool registry.
"""
function ToolRegistry()
    ToolRegistry(
        Dict{String, AbstractTool}(),
        Dict{Symbol, Vector{String}}(),
        Set{String}()
    )
end

"""
    register!(registry::ToolRegistry, tool::AbstractTool)

Register a tool with the registry.
"""
function register!(registry::ToolRegistry, tool::AbstractTool)
    tool_info = info(tool)

    # Add to tools dict
    registry.tools[tool_info.id] = tool

    # Add to category
    if !haskey(registry.categories, tool_info.category)
        registry.categories[tool_info.category] = String[]
    end
    push!(registry.categories[tool_info.category], tool_info.id)

    # Enable by default
    push!(registry.enabled, tool_info.id)

    registry
end

"""
    unregister!(registry::ToolRegistry, tool_id::String)

Remove a tool from the registry.
"""
function unregister!(registry::ToolRegistry, tool_id::String)
    if haskey(registry.tools, tool_id)
        tool_info = info(registry.tools[tool_id])

        # Remove from tools
        delete!(registry.tools, tool_id)

        # Remove from category
        if haskey(registry.categories, tool_info.category)
            filter!(id -> id != tool_id, registry.categories[tool_info.category])
        end

        # Remove from enabled
        delete!(registry.enabled, tool_id)
    end

    registry
end

"""
    get_tool(registry::ToolRegistry, tool_id::String)

Get a tool by ID.
"""
function get_tool(registry::ToolRegistry, tool_id::String)::Union{AbstractTool, Nothing}
    get(registry.tools, tool_id, nothing)
end

"""
    get_tool(registry::ToolRegistry, tool_name::String)

Get a tool by name (searches through all tools).
"""
function get_tool_by_name(registry::ToolRegistry, tool_name::String)::Union{AbstractTool, Nothing}
    for (id, tool) in registry.tools
        if info(tool).name == tool_name
            return tool
        end
    end
    nothing
end

"""
    enable!(registry::ToolRegistry, tool_id::String)

Enable a tool.
"""
function enable!(registry::ToolRegistry, tool_id::String)
    if haskey(registry.tools, tool_id)
        push!(registry.enabled, tool_id)
    end
    registry
end

"""
    disable!(registry::ToolRegistry, tool_id::String)

Disable a tool.
"""
function disable!(registry::ToolRegistry, tool_id::String)
    delete!(registry.enabled, tool_id)
    registry
end

"""
    is_enabled(registry::ToolRegistry, tool_id::String)

Check if a tool is enabled.
"""
function is_enabled(registry::ToolRegistry, tool_id::String)::Bool
    tool_id in registry.enabled
end

"""
    get_tools_for_category(registry::ToolRegistry, category::Symbol)

Get all enabled tools in a category.
"""
function get_tools_for_category(registry::ToolRegistry, category::Symbol)::Vector{AbstractTool}
    tool_ids = get(registry.categories, category, String[])
    [registry.tools[id] for id in tool_ids if id in registry.enabled]
end

"""
    list_tools(registry::ToolRegistry)

List all enabled tools.
"""
function list_tools(registry::ToolRegistry)::Vector{AbstractTool}
    [tool for (id, tool) in registry.tools if id in registry.enabled]
end

"""
    list_tool_infos(registry::ToolRegistry)

List tool info for all enabled tools.
"""
function list_tool_infos(registry::ToolRegistry)::Vector{ToolInfo}
    [info(tool) for tool in list_tools(registry)]
end

"""
    list_categories(registry::ToolRegistry)

List all tool categories.
"""
function list_categories(registry::ToolRegistry)::Vector{Symbol}
    collect(keys(registry.categories))
end

"""
    execute_tool(registry::ToolRegistry, tool_id::String, args::Dict, ctx::ToolContext)

Execute a tool by ID.
"""
function execute_tool(registry::ToolRegistry, tool_id::String, args::Dict, ctx::ToolContext)::ToolResult
    tool = get_tool(registry, tool_id)

    if isnothing(tool)
        return error_result("Tool not found: $tool_id")
    end

    if !is_enabled(registry, tool_id)
        return error_result("Tool is disabled: $tool_id")
    end

    if !validate_args(tool, args)
        return error_result("Invalid arguments for tool: $tool_id")
    end

    execute(tool, args, ctx)
end
