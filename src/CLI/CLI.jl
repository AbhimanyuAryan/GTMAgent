# CLI interface for GTM Agent

using ArgParse

"""
    parse_commandline()

Parse command line arguments.
"""
function parse_commandline()
    s = ArgParseSettings(
        prog = "gtm-agent",
        description = "GTM Agent - AI-powered Go-to-Market strategy assistant",
        version = "0.1.0"
    )

    @add_arg_table! s begin
        "--model", "-m"
            help = "Model to use (e.g., claude-sonnet-4-20250514)"
            arg_type = String
            default = ""
        "--provider", "-p"
            help = "Provider to use (anthropic, openai, local)"
            arg_type = String
            default = "anthropic"
        "--temperature", "-t"
            help = "Temperature for model responses (0.0-1.0)"
            arg_type = Float64
            default = 0.7
        "--max-steps"
            help = "Maximum number of agent steps"
            arg_type = Int
            default = 50
        "--config", "-c"
            help = "Path to configuration file"
            arg_type = String
            default = ""
        "--verbose", "-v"
            help = "Enable verbose output"
            action = :store_true
        "--no-tools"
            help = "Disable tool usage"
            action = :store_true
        "--session", "-s"
            help = "Resume a previous session by ID"
            arg_type = String
            default = ""
        "--prompt"
            help = "Initial prompt (optional, enters REPL mode if not provided)"
            arg_type = String
            default = ""
    end

    parse_args(s)
end

"""
    setup_agent(args::Dict)

Set up the agent based on command line arguments.
"""
function setup_agent(args::Dict)
    # Load configuration
    config_mgr = load_config()
    agent_config = config_to_agent_config(config_mgr)

    # Override with command line arguments
    if !isempty(args["model"])
        agent_config = AgentConfig(
            name = agent_config.name,
            mode = agent_config.mode,
            permissions = agent_config.permissions,
            model = ModelConfig(
                provider = agent_config.model.provider,
                model = args["model"],
                temperature = args["temperature"],
                max_tokens = agent_config.model.max_tokens
            ),
            max_steps = args["max-steps"],
            domain_focus = agent_config.domain_focus,
            system_prompt = agent_config.system_prompt
        )
    end

    if args["temperature"] != 0.7
        agent_config = AgentConfig(
            name = agent_config.name,
            mode = agent_config.mode,
            permissions = agent_config.permissions,
            model = ModelConfig(
                provider = agent_config.model.provider,
                model = agent_config.model.model,
                temperature = args["temperature"],
                max_tokens = agent_config.model.max_tokens
            ),
            max_steps = agent_config.max_steps,
            domain_focus = agent_config.domain_focus,
            system_prompt = agent_config.system_prompt
        )
    end

    # Create provider
    provider = if args["provider"] == "anthropic"
        AnthropicProvider(
            model = agent_config.model.model,
            temperature = agent_config.model.temperature,
            max_tokens = agent_config.model.max_tokens
        )
    else
        error("Unsupported provider: $(args["provider"])")
    end

    # Create agent
    agent = GTMAgentInstance(agent_config, provider)

    # Set up tools unless disabled
    if !args["no-tools"]
        registry = create_default_registry()
        set_tools!(agent, registry)
    end

    # Set up inspector pipeline
    inspector = InspectorPipeline(agent_config.permissions)
    set_inspector!(agent, inspector)

    agent
end

"""
    print_banner()

Print the GTM Agent banner.
"""
function print_banner()
    println("""

    ╔═══════════════════════════════════════════════════════════════╗
    ║                                                               ║
    ║   GTM Agent v0.1.0                                            ║
    ║   AI-powered Go-to-Market Strategy Assistant                  ║
    ║                                                               ║
    ║   Type 'help' for commands, 'exit' to quit                    ║
    ║                                                               ║
    ╚═══════════════════════════════════════════════════════════════╝

    """)
end

"""
    print_help()

Print help information.
"""
function print_help()
    println("""
    Available Commands:
    ──────────────────────────────────────────────────────────────────
    help           - Show this help message
    exit / quit    - Exit the agent
    clear          - Clear conversation history
    tools          - List available tools
    status         - Show agent status
    health <id>    - Calculate health score for customer
    pipeline       - Analyze sales pipeline
    risk           - Show at-risk customers
    ──────────────────────────────────────────────────────────────────

    You can also ask natural language questions about:
    - Customer health and churn risk
    - Sales pipeline and forecasting
    - Competitive intelligence
    - Market analysis and sizing
    - Customer success playbooks
    """)
end

"""
    handle_command(agent::GTMAgentInstance, input::String)

Handle special commands.
"""
function handle_command(agent::GTMAgentInstance, input::String)
    cmd = lowercase(strip(input))

    if cmd in ["exit", "quit", "q"]
        return :exit
    elseif cmd == "help"
        print_help()
        return :continue
    elseif cmd == "clear"
        reset!(agent)
        println("Conversation cleared.")
        return :continue
    elseif cmd == "tools"
        if !isnothing(agent.tools)
            println("\nAvailable Tools:")
            println("─────────────────────────────────────")
            for tool in list_tools(agent.tools)
                ti = info(tool)
                println("  $(ti.name) - $(ti.description[1:min(50, length(ti.description))])...")
            end
            println()
        else
            println("No tools configured.")
        end
        return :continue
    elseif cmd == "status"
        println("\nAgent Status:")
        println("─────────────────────────────────────")
        println("  Name: $(agent.config.name)")
        println("  Model: $(agent.config.model.model)")
        println("  Provider: $(agent.config.model.provider)")
        println("  Steps: $(agent.step_count) / $(agent.config.max_steps)")
        println("  Messages: $(length(agent.session.conversation.messages))")
        println()
        return :continue
    end

    return :chat
end

"""
    run_cli()

Main entry point for the CLI.
"""
function run_cli()
    args = parse_commandline()

    # Set up agent
    agent = setup_agent(args)

    # Check for single prompt mode
    if !isempty(args["prompt"])
        # Single prompt mode
        response = chat!(agent, args["prompt"])
        println(response)
        return
    end

    # Interactive REPL mode
    run_repl(agent)
end

"""
    main()

Main entry point.
"""
function main()
    try
        run_cli()
    catch e
        if e isa InterruptException
            println("\nGoodbye!")
        else
            @error "Error" exception=(e, catch_backtrace())
            rethrow(e)
        end
    end
end
