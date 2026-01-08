# Permission inspector pipeline for GTM Agent

"""
    Inspector

Abstract type for permission inspectors.
"""
abstract type Inspector end

"""
    InspectorResult

Result from an inspector check.
"""
struct InspectorResult
    status::Symbol  # :approved, :denied, :needs_approval
    reason::String
    modified_args::Union{Dict, Nothing}
end

approved() = InspectorResult(:approved, "", nothing)
denied(reason::String) = InspectorResult(:denied, reason, nothing)
needs_approval(reason::String) = InspectorResult(:needs_approval, reason, nothing)

"""
    inspect(inspector::Inspector, tool::AbstractTool, args::Dict, ctx)

Inspect a tool call. Must be implemented by all inspectors.
"""
function inspect(inspector::Inspector, tool, args::Dict, ctx)::InspectorResult
    error("inspect() not implemented for $(typeof(inspector))")
end

# ============================================================================
# Security Inspector
# ============================================================================

"""
    SecurityInspector

Checks for dangerous or bulk operations.
"""
struct SecurityInspector <: Inspector end

function inspect(::SecurityInspector, tool, args::Dict, ctx)::InspectorResult
    # Check for bulk operations
    if haskey(args, "limit") && args["limit"] > 1000
        return needs_approval("Bulk operation affecting >1000 records")
    end

    # Check for bulk email operations
    if haskey(args, "batch_size") && args["batch_size"] > 100
        return needs_approval("Bulk email operation requires approval")
    end

    # Check for delete operations
    tool_info = info(tool)
    if contains(tool_info.id, "delete")
        return needs_approval("Data deletion requires explicit approval")
    end

    approved()
end

# ============================================================================
# Permission Inspector
# ============================================================================

"""
    PermissionInspector

Checks tool permissions against configuration.
"""
struct PermissionInspector <: Inspector
    config::PermissionConfig
end

function inspect(insp::PermissionInspector, tool, args::Dict, ctx)::InspectorResult
    tool_info = info(tool)

    # Check tool-specific permission
    permission = get(insp.config.tool_permissions, tool_info.id, ALLOW)

    if permission == DENY
        return denied("Tool $(tool_info.id) is not permitted")
    elseif permission == ASK
        return needs_approval("Tool $(tool_info.id) requires approval")
    end

    # Check category permissions
    category = tool_info.category
    if category == :crm
        for perm in tool_info.required_permissions
            if perm == :crm_write && insp.config.crm_write == DENY
                return denied("CRM write operations are not permitted")
            elseif perm == :crm_write && insp.config.crm_write == ASK
                return needs_approval("CRM write operation requires approval")
            end
        end
    end

    approved()
end

# ============================================================================
# Data Access Inspector
# ============================================================================

"""
    DataAccessInspector

Checks for access to sensitive data.
"""
struct DataAccessInspector <: Inspector end

function inspect(::DataAccessInspector, tool, args::Dict, ctx)::InspectorResult
    # Check for sensitive field access
    if haskey(args, "fields")
        sensitive_fields = ["billing_info", "payment_method", "ssn", "credit_card", "bank_account"]
        requested = args["fields"]

        if requested isa Vector
            for field in requested
                if field in sensitive_fields
                    return needs_approval("Accessing sensitive data field: $field")
                end
            end
        elseif requested isa String && requested in sensitive_fields
            return needs_approval("Accessing sensitive data field: $requested")
        end
    end

    # Check for PII access
    if haskey(args, "include_pii") && args["include_pii"] == true
        return needs_approval("Accessing PII data requires approval")
    end

    approved()
end

# ============================================================================
# Rate Limit Inspector
# ============================================================================

"""
    RateLimitInspector

Checks for rate limiting on API calls.
"""
mutable struct RateLimitInspector <: Inspector
    call_counts::Dict{String, Int}
    window_start::DateTime
    max_calls_per_minute::Int
end

RateLimitInspector(max_calls::Int=60) =
    RateLimitInspector(Dict{String, Int}(), now(UTC), max_calls)

function inspect(insp::RateLimitInspector, tool, args::Dict, ctx)::InspectorResult
    tool_info = info(tool)

    # Reset window if needed
    if now(UTC) - insp.window_start > Minute(1)
        empty!(insp.call_counts)
        insp.window_start = now(UTC)
    end

    # Check rate limit
    current_count = get(insp.call_counts, tool_info.id, 0)
    if current_count >= insp.max_calls_per_minute
        return denied("Rate limit exceeded for $(tool_info.id)")
    end

    # Increment count
    insp.call_counts[tool_info.id] = current_count + 1

    approved()
end

# ============================================================================
# Inspector Pipeline
# ============================================================================

"""
    InspectorPipeline

Pipeline of inspectors to run on each tool call.
"""
struct InspectorPipeline
    inspectors::Vector{Inspector}
end

"""
    InspectorPipeline()

Create a default inspector pipeline.
"""
function InspectorPipeline()
    InspectorPipeline(Inspector[])
end

"""
    InspectorPipeline(config::PermissionConfig)

Create an inspector pipeline with default inspectors.
"""
function InspectorPipeline(config::PermissionConfig)
    InspectorPipeline([
        SecurityInspector(),
        PermissionInspector(config),
        DataAccessInspector(),
        RateLimitInspector()
    ])
end

"""
    add_inspector!(pipeline::InspectorPipeline, inspector::Inspector)

Add an inspector to the pipeline.
"""
function add_inspector!(pipeline::InspectorPipeline, inspector::Inspector)
    push!(pipeline.inspectors, inspector)
    pipeline
end

"""
    run_inspection(pipeline::InspectorPipeline, tool, args::Dict, ctx)

Run all inspectors in the pipeline.
"""
function run_inspection(pipeline::InspectorPipeline, tool, args::Dict, ctx)::InspectorResult
    for inspector in pipeline.inspectors
        result = inspect(inspector, tool, args, ctx)
        if result.status != :approved
            return result
        end
    end
    approved()
end
