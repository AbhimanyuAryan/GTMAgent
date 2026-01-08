# Configuration management for GTM Agent

"""
    ConfigSource

A source of configuration with priority.
"""
struct ConfigSource
    name::String
    priority::Int
    data::Dict{String, Any}
end

"""
    ConfigManager

Manages configuration from multiple sources.
"""
struct ConfigManager
    sources::Vector{ConfigSource}
    merged::Dict{String, Any}
end

"""
Default configuration values.
"""
const DEFAULT_CONFIG = Dict{String, Any}(
    "agent" => Dict{String, Any}(
        "name" => "gtm-agent",
        "max_steps" => 50,
        "temperature" => 0.7
    ),
    "provider" => Dict{String, Any}(
        "default" => "anthropic",
        "anthropic" => Dict{String, Any}(
            "model" => "claude-sonnet-4-20250514"
        ),
        "openai" => Dict{String, Any}(
            "model" => "gpt-4o"
        )
    ),
    "integrations" => Dict{String, Any}(
        "salesforce" => Dict{String, Any}("enabled" => false),
        "hubspot" => Dict{String, Any}("enabled" => false),
        "amplitude" => Dict{String, Any}("enabled" => false)
    ),
    "permissions" => Dict{String, Any}(
        "crm_read" => "allow",
        "crm_write" => "ask",
        "send_email" => "ask",
        "run_playbook" => "ask"
    )
)

"""
    deep_merge(base::Dict, overlay::Dict)

Deep merge two dictionaries, with overlay taking precedence.
"""
function deep_merge(base::Dict, overlay::Dict)
    result = copy(base)
    for (key, value) in overlay
        if haskey(result, key) && result[key] isa Dict && value isa Dict
            result[key] = deep_merge(result[key], value)
        else
            result[key] = value
        end
    end
    result
end

"""
    load_yaml_config(path::String)

Load configuration from a YAML file.
"""
function load_yaml_config(path::String)::Dict{String, Any}
    if !isfile(path)
        return Dict{String, Any}()
    end

    try
        YAML.load_file(path)
    catch e
        @warn "Failed to load config from $path" exception=e
        Dict{String, Any}()
    end
end

"""
    load_env_config()

Load configuration from environment variables.
"""
function load_env_config()::Dict{String, Any}
    config = Dict{String, Any}()

    # Provider configuration
    if haskey(ENV, "GTM_AGENT_PROVIDER")
        config["provider"] = Dict{String, Any}("default" => ENV["GTM_AGENT_PROVIDER"])
    end

    if haskey(ENV, "GTM_AGENT_MODEL")
        provider = get(config, "provider", Dict{String, Any}())
        provider_name = get(provider, "default", "anthropic")
        if !haskey(config, "provider")
            config["provider"] = Dict{String, Any}()
        end
        if !haskey(config["provider"], provider_name)
            config["provider"][provider_name] = Dict{String, Any}()
        end
        config["provider"][provider_name]["model"] = ENV["GTM_AGENT_MODEL"]
    end

    # Agent configuration
    if haskey(ENV, "GTM_AGENT_MAX_STEPS")
        if !haskey(config, "agent")
            config["agent"] = Dict{String, Any}()
        end
        config["agent"]["max_steps"] = parse(Int, ENV["GTM_AGENT_MAX_STEPS"])
    end

    if haskey(ENV, "GTM_AGENT_TEMPERATURE")
        if !haskey(config, "agent")
            config["agent"] = Dict{String, Any}()
        end
        config["agent"]["temperature"] = parse(Float64, ENV["GTM_AGENT_TEMPERATURE"])
    end

    config
end

"""
    load_config()

Load configuration from all sources.
"""
function load_config()::ConfigManager
    sources = ConfigSource[]

    # 1. Default configuration
    push!(sources, ConfigSource("defaults", 0, DEFAULT_CONFIG))

    # 2. User configuration
    user_config_path = joinpath(homedir(), ".config", "gtm-agent", "config.yaml")
    if isfile(user_config_path)
        push!(sources, ConfigSource("user", 10, load_yaml_config(user_config_path)))
    end

    # 3. Project configuration
    project_config_path = "gtm-agent.yaml"
    if isfile(project_config_path)
        push!(sources, ConfigSource("project", 20, load_yaml_config(project_config_path)))
    end

    # 4. Environment variables
    env_config = load_env_config()
    if !isempty(env_config)
        push!(sources, ConfigSource("environment", 30, env_config))
    end

    # Sort by priority and merge
    sort!(sources, by = s -> s.priority)

    merged = Dict{String, Any}()
    for source in sources
        merged = deep_merge(merged, source.data)
    end

    ConfigManager(sources, merged)
end

"""
    get_config(mgr::ConfigManager, path::String; default=nothing)

Get a configuration value by path (e.g., "provider.anthropic.model").
"""
function get_config(mgr::ConfigManager, path::String; default=nothing)
    parts = split(path, ".")
    current = mgr.merged

    for part in parts
        if current isa Dict && haskey(current, part)
            current = current[part]
        else
            return default
        end
    end

    current
end

"""
    config_to_agent_config(mgr::ConfigManager)

Convert ConfigManager to AgentConfig.
"""
function config_to_agent_config(mgr::ConfigManager)::AgentConfig
    agent = get_config(mgr, "agent", default=Dict())
    provider_config = get_config(mgr, "provider", default=Dict())
    permissions = get_config(mgr, "permissions", default=Dict())

    # Build PermissionConfig
    perm_config = PermissionConfig(
        crm_read = parse_permission(get(permissions, "crm_read", "allow")),
        crm_write = parse_permission(get(permissions, "crm_write", "ask")),
        send_email = parse_permission(get(permissions, "send_email", "ask")),
        run_playbook = parse_permission(get(permissions, "run_playbook", "ask"))
    )

    # Build ModelConfig
    default_provider = get(provider_config, "default", "anthropic")
    provider_settings = get(provider_config, default_provider, Dict())

    model_config = ModelConfig(
        provider = default_provider,
        model = get(provider_settings, "model", "claude-sonnet-4-20250514"),
        temperature = get(agent, "temperature", 0.7),
        max_tokens = get(agent, "max_tokens", 4096)
    )

    AgentConfig(
        name = get(agent, "name", "gtm-agent"),
        permissions = perm_config,
        model = model_config,
        max_steps = get(agent, "max_steps", 50)
    )
end

"""
    parse_permission(value::String)

Parse a permission string to PermissionLevel.
"""
function parse_permission(value::String)::PermissionLevel
    lower = lowercase(value)
    if lower == "allow"
        ALLOW
    elseif lower == "deny"
        DENY
    elseif lower == "ask"
        ASK
    else
        ALLOW
    end
end
