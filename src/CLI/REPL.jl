# REPL interface for GTM Agent

"""
    run_repl(agent::GTMAgentInstance)

Run the interactive REPL mode.
"""
function run_repl(agent::GTMAgentInstance)
    print_banner()

    while true
        # Print prompt
        print("\n\e[1;36mgtm>\e[0m ")

        # Read input
        input = try
            readline()
        catch e
            if e isa InterruptException
                println("\nUse 'exit' to quit.")
                continue
            end
            rethrow(e)
        end

        # Skip empty input
        if isempty(strip(input))
            continue
        end

        # Handle commands
        result = handle_command(agent, input)

        if result == :exit
            println("\nGoodbye!")
            break
        elseif result == :continue
            continue
        end

        # Process as chat message
        print("\n\e[1;33mThinking...\e[0m")

        try
            response = chat!(agent, input)

            # Clear "Thinking..." and print response
            print("\r\e[K")
            println("\n\e[1;32mAssistant:\e[0m")
            println("─────────────────────────────────────────────────────────")
            println(response)
            println("─────────────────────────────────────────────────────────")

            # Show tool usage if any
            last_msg = agent.session.conversation.messages[end]
            if has_tool_calls(last_msg)
                tool_calls = get_tool_calls(last_msg)
                println("\n\e[90m[Used $(length(tool_calls)) tool(s)]\e[0m")
            end
        catch e
            print("\r\e[K")
            if e isa InterruptException
                println("\nInterrupted.")
            else
                println("\n\e[1;31mError:\e[0m $(e)")
                if hasfield(typeof(e), :msg)
                    println(e.msg)
                end
            end
        end
    end
end

"""
    run_single_prompt(agent::GTMAgentInstance, prompt::String)

Run a single prompt and print the response.
"""
function run_single_prompt(agent::GTMAgentInstance, prompt::String)
    response = chat!(agent, prompt)
    println(response)
end

"""
    stream_response(agent::GTMAgentInstance, prompt::String)

Stream a response to the console.
"""
function stream_response(agent::GTMAgentInstance, prompt::String)
    # Add user message
    user_msg = user_message(prompt)
    add_message!(agent.session.conversation, user_msg)

    # Get streaming response
    if !isnothing(agent.provider)
        system_prompt = get_system_prompt(agent)
        messages = get_messages_for_api(agent.session.conversation)
        tools = if !isnothing(agent.tools)
            list_tool_infos(agent.tools)
        else
            []
        end

        ch = stream_complete(agent.provider, system_prompt, messages, tools)

        for msg in ch
            text = get_text_content(msg)
            print(text)
        end
        println()
    end
end

"""
    format_tool_result(result::ToolResult)

Format a tool result for display.
"""
function format_tool_result(result::ToolResult)
    if result.success
        if result.output isa Dict
            # Pretty print dictionary
            lines = String[]
            for (key, value) in result.output
                push!(lines, "  $key: $value")
            end
            join(lines, "\n")
        else
            string(result.output)
        end
    else
        "Error: $(result.output)"
    end
end

"""
    display_customer_health(health::Dict)

Display customer health score in a formatted way.
"""
function display_customer_health(health::Dict)
    println("\n╔═══════════════════════════════════════════╗")
    println("║  Customer Health Score                    ║")
    println("╠═══════════════════════════════════════════╣")

    overall = get(health, "overall", 0.0)
    color = if overall >= 80
        "\e[32m"  # Green
    elseif overall >= 60
        "\e[33m"  # Yellow
    else
        "\e[31m"  # Red
    end

    println("║  Overall: $(color)$(round(overall, digits=1))\e[0m")
    println("║")

    for (key, value) in health
        if key in ["engagement", "sentiment", "financial", "relationship", "adoption"]
            println("║  $(titlecase(key)): $(round(Float64(value), digits=1))")
        end
    end

    println("╚═══════════════════════════════════════════╝")
end
