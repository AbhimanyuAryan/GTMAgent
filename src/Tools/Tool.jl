# Tool interface for GTM Agent

"""
    AbstractTool

Abstract base type for all tools.
"""
abstract type AbstractTool end

"""
    ParameterDef

Definition of a tool parameter.
"""
struct ParameterDef
    name::String
    type::Type
    description::String
    required::Bool
    default::Any
end

ParameterDef(name::String, type::Type, description::String; required::Bool=false, default=nothing) =
    ParameterDef(name, type, description, required, default)

"""
    ParameterSchema

Schema for tool parameters.
"""
struct ParameterSchema
    parameters::Vector{ParameterDef}
    additional_properties::Bool
end

ParameterSchema(params::Vector{ParameterDef}) = ParameterSchema(params, false)
ParameterSchema() = ParameterSchema(ParameterDef[], false)

"""
Convert ParameterSchema to JSON Schema format for API.
"""
function to_json_schema(schema::ParameterSchema)
    properties = Dict{String, Any}()
    required = String[]

    for param in schema.parameters
        prop = Dict{String, Any}(
            "type" => julia_type_to_json(param.type),
            "description" => param.description
        )

        if !isnothing(param.default)
            prop["default"] = param.default
        end

        properties[param.name] = prop

        if param.required
            push!(required, param.name)
        end
    end

    Dict{String, Any}(
        "type" => "object",
        "properties" => properties,
        "required" => required,
        "additionalProperties" => schema.additional_properties
    )
end

"""
Convert Julia type to JSON Schema type.
"""
function julia_type_to_json(t::Type)
    if t <: Integer
        "integer"
    elseif t <: AbstractFloat
        "number"
    elseif t <: Bool
        "boolean"
    elseif t <: AbstractString
        "string"
    elseif t <: AbstractVector
        "array"
    elseif t <: AbstractDict
        "object"
    else
        "string"
    end
end

"""
    ToolInfo

Metadata about a tool.
"""
struct ToolInfo
    id::String
    name::String
    description::String
    category::Symbol
    parameters::Dict{String, Any}  # JSON Schema format
    required_permissions::Vector{Symbol}
end

function ToolInfo(;
    id::String,
    name::String,
    description::String,
    category::Symbol = :general,
    parameters::ParameterSchema = ParameterSchema(),
    required_permissions::Vector{Symbol} = Symbol[]
)
    ToolInfo(id, name, description, category, to_json_schema(parameters), required_permissions)
end

"""
    ToolContext

Context for tool execution.
"""
struct ToolContext
    session_id::UUID
    message_id::UUID
    agent::Any
    abort_signal::Channel{Bool}
    tool_id::String
end

"""
    ToolResult

Result from tool execution.
"""
struct ToolResult
    success::Bool
    output::Any
    metadata::Dict{String, Any}
    suggested_followups::Vector{String}
end

ToolResult(; success::Bool, output::Any, metadata::Dict{String, Any}=Dict{String, Any}(), suggested_followups::Vector{String}=String[]) =
    ToolResult(success, output, metadata, suggested_followups)

# Success result helper
success_result(output; metadata=Dict{String, Any}(), followups=String[]) =
    ToolResult(true, output, metadata, followups)

# Error result helper
error_result(message; metadata=Dict{String, Any}()) =
    ToolResult(false, message, metadata, String[])

"""
    info(tool::AbstractTool)

Get the tool's metadata. Must be implemented by all tools.
"""
function info(tool::AbstractTool)::ToolInfo
    error("info() not implemented for $(typeof(tool))")
end

"""
    execute(tool::AbstractTool, args::Dict, ctx::ToolContext)

Execute the tool with given arguments. Must be implemented by all tools.
"""
function execute(tool::AbstractTool, args::Dict, ctx::ToolContext)::ToolResult
    error("execute() not implemented for $(typeof(tool))")
end

"""
    validate_args(tool::AbstractTool, args::Dict)

Validate tool arguments against schema. Default implementation.
"""
function validate_args(tool::AbstractTool, args::Dict)::Bool
    tool_info = info(tool)
    schema = tool_info.parameters

    # Check required parameters
    required = get(schema, "required", String[])
    for req in required
        if !haskey(args, req)
            return false
        end
    end

    true
end
