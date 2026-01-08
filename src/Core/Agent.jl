# Agent core implementation for GTM Agent

"""
    AbstractAgent

Abstract base type for all agents.
"""
abstract type AbstractAgent end

# Forward declarations - these will be defined in other files
# AbstractProvider is defined in Providers/Provider.jl
# ToolRegistry is defined in Tools/Registry.jl
# InspectorPipeline is defined in Permission/Inspector.jl

"""
    GTMAgentInstance

The main GTM Agent implementation.
"""
mutable struct GTMAgentInstance <: AbstractAgent
    config::AgentConfig
    provider::Any  # AbstractProvider - using Any to avoid circular dependency
    tools::Any     # ToolRegistry - using Any to avoid circular dependency
    session::Session
    inspector_pipeline::Any  # InspectorPipeline - using Any to avoid circular dependency
    running::Bool
    step_count::Int
end

"""
    GTMAgentInstance(config::AgentConfig, provider)

Create a new GTM Agent instance.
"""
function GTMAgentInstance(config::AgentConfig, provider)
    GTMAgentInstance(
        config,
        provider,
        nothing,  # tools will be set later
        Session(),
        nothing,  # inspector_pipeline will be set later
        false,
        0
    )
end

"""
    GTMAgentInstance(config::AgentConfig)

Create a GTM Agent with default provider.
"""
function GTMAgentInstance(config::AgentConfig)
    # Will be initialized with provider later
    GTMAgentInstance(
        config,
        nothing,
        nothing,
        Session(),
        nothing,
        false,
        0
    )
end

"""
    GTMAgentInstance()

Create a GTM Agent with default configuration.
"""
function GTMAgentInstance()
    GTMAgentInstance(AgentConfig())
end

# GTM-specific system prompt
const GTM_SYSTEM_PROMPT = """
You are a Go-to-Market (GTM) Strategy Agent specialized in Customer Success. Your expertise includes:

## Core Competencies
- **Customer Success Management**: Health scoring, churn prediction, expansion identification
- **Revenue Operations**: Pipeline analysis, forecasting, velocity optimization
- **Market Intelligence**: Competitive analysis, market sizing, positioning
- **GTM Strategy**: Segmentation, pricing, channel strategy, product-market fit

## Your Approach
1. Always ground recommendations in data from available tools
2. Consider both leading indicators (engagement, sentiment) and lagging indicators (revenue, churn)
3. Prioritize actionable insights over theoretical frameworks
4. Quantify impact when possible (ARR at risk, expansion potential, etc.)

## Available Tools
You have access to CRM systems, analytics platforms, and market intelligence sources. Use them proactively to:
- Pull relevant customer data before making recommendations
- Validate hypotheses with actual metrics
- Identify patterns across the customer base

## Communication Style
- Be direct and specific
- Lead with the insight, then provide supporting data
- Suggest concrete next steps
- Flag risks and opportunities with urgency levels
"""

"""
    get_system_prompt(agent::GTMAgentInstance)

Get the system prompt for the agent.
"""
function get_system_prompt(agent::GTMAgentInstance)
    if !isempty(agent.config.system_prompt)
        return agent.config.system_prompt
    end
    GTM_SYSTEM_PROMPT
end

"""
    chat!(agent::GTMAgentInstance, user_input::String)

Process a user message and return the agent's response.
"""
function chat!(agent::GTMAgentInstance, user_input::String)
    # Add user message to conversation
    user_msg = user_message(user_input)
    add_message!(agent.session.conversation, user_msg)

    # Check if provider is set
    if isnothing(agent.provider)
        error("No provider configured for agent")
    end

    # Run the agent loop
    response = run_agent_loop!(agent)

    response
end

"""
    run_agent_loop!(agent::GTMAgentInstance)

Run the main agent loop until completion or max steps.
"""
function run_agent_loop!(agent::GTMAgentInstance)
    agent.running = true
    agent.step_count = 0
    last_response = ""

    while agent.running && agent.step_count < agent.config.max_steps
        agent.step_count += 1

        # Get completion from provider
        response = get_completion(agent)

        if isnothing(response)
            break
        end

        # Add assistant message to conversation
        add_message!(agent.session.conversation, response)

        # Check for tool calls
        tool_calls = get_tool_calls(response)

        if isempty(tool_calls)
            # No tool calls - we're done
            last_response = get_text_content(response)
            agent.running = false
        else
            # Execute tool calls
            for tc in tool_calls
                result = execute_tool_call(agent, tc)
                add_tool_result!(agent.session.conversation, tc.tool_id, result.output, !result.success)
            end
        end
    end

    agent.running = false
    last_response
end

"""
    get_completion(agent::GTMAgentInstance)

Get a completion from the provider.
"""
function get_completion(agent::GTMAgentInstance)
    # Build request
    system_prompt = get_system_prompt(agent)
    messages = get_messages_for_api(agent.session.conversation)

    # Get tool definitions if available
    tools = if !isnothing(agent.tools)
        list_tool_infos(agent.tools)
    else
        []
    end

    # Call provider
    complete(agent.provider, system_prompt, messages, tools)
end

"""
    execute_tool_call(agent::GTMAgentInstance, tc::ToolCallPart)

Execute a single tool call.
"""
function execute_tool_call(agent::GTMAgentInstance, tc::ToolCallPart)
    tc.state = :executing

    if isnothing(agent.tools)
        tc.state = :failed
        return (success=false, output="No tools registered")
    end

    # Get tool from registry
    tool = get_tool(agent.tools, tc.tool_name)

    if isnothing(tool)
        tc.state = :failed
        return (success=false, output="Tool not found: $(tc.tool_name)")
    end

    # Create tool context
    ctx = create_tool_context(agent, tc)

    # Check permissions via inspector pipeline
    if !isnothing(agent.inspector_pipeline)
        inspection = run_inspection(agent.inspector_pipeline, tool, tc.arguments, ctx)
        if inspection.status == :denied
            tc.state = :failed
            return (success=false, output="Permission denied: $(inspection.reason)")
        elseif inspection.status == :needs_approval
            # In a real implementation, this would prompt the user
            tc.state = :failed
            return (success=false, output="Needs approval: $(inspection.reason)")
        end
    end

    # Execute tool
    try
        result = execute(tool, tc.arguments, ctx)
        tc.state = :completed
        result
    catch e
        tc.state = :failed
        (success=false, output="Tool execution error: $e")
    end
end

"""
    create_tool_context(agent::GTMAgentInstance, tc::ToolCallPart)

Create a context for tool execution.
"""
function create_tool_context(agent::GTMAgentInstance, tc::ToolCallPart)
    (
        session_id = agent.session.id,
        message_id = uuid4(),
        agent = agent,
        abort_signal = Channel{Bool}(1),
        tool_id = tc.tool_id
    )
end

"""
    reset!(agent::GTMAgentInstance)

Reset the agent's session.
"""
function reset!(agent::GTMAgentInstance)
    agent.session = Session()
    agent.running = false
    agent.step_count = 0
end

"""
    set_tools!(agent::GTMAgentInstance, tools)

Set the tool registry for the agent.
"""
function set_tools!(agent::GTMAgentInstance, tools)
    agent.tools = tools
end

"""
    set_inspector!(agent::GTMAgentInstance, pipeline)

Set the inspector pipeline for the agent.
"""
function set_inspector!(agent::GTMAgentInstance, pipeline)
    agent.inspector_pipeline = pipeline
end
