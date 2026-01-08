using Test
using GTMAgent

@testset "GTMAgent Tests" begin

    @testset "Core Types" begin
        @testset "Message Types" begin
            # Test TextPart
            text = GTMAgent.TextPart("Hello, world!")
            @test text.content == "Hello, world!"

            # Test Message creation
            msg = GTMAgent.Message(GTMAgent.USER, "Test message")
            @test msg.role == GTMAgent.USER
            @test length(msg.parts) == 1
            @test msg.parts[1] isa GTMAgent.TextPart

            # Test user_message helper
            user_msg = GTMAgent.user_message("Hello")
            @test user_msg.role == GTMAgent.USER
            @test GTMAgent.get_text_content(user_msg) == "Hello"

            # Test ToolCallPart
            tc = GTMAgent.ToolCallPart("id1", "test_tool", Dict{String, Any}("arg" => "value"))
            @test tc.tool_id == "id1"
            @test tc.tool_name == "test_tool"
            @test tc.state == :pending
        end

        @testset "Conversation" begin
            conv = GTMAgent.Conversation()
            @test length(conv.messages) == 0

            # Add message
            msg = GTMAgent.user_message("Test")
            GTMAgent.add_message!(conv, msg)
            @test length(conv.messages) == 1

            # Clear
            GTMAgent.clear!(conv)
            @test length(conv.messages) == 0
        end

        @testset "Session" begin
            session = GTMAgent.Session()
            @test !isnothing(session.id)
            @test length(session.conversation.messages) == 0
        end

        @testset "AgentConfig" begin
            config = GTMAgent.AgentConfig()
            @test config.name == "gtm-agent"
            @test config.max_steps == 50
            @test config.model.provider == "anthropic"
        end
    end

    @testset "Tool System" begin
        @testset "ToolResult" begin
            result = GTMAgent.success_result("test output")
            @test result.success == true
            @test result.output == "test output"

            error_res = GTMAgent.error_result("test error")
            @test error_res.success == false
        end

        @testset "ToolRegistry" begin
            registry = GTMAgent.ToolRegistry()
            @test length(GTMAgent.list_tools(registry)) == 0

            # Register a tool
            GTMAgent.register!(registry, GTMAgent.HealthScoreTool())
            @test length(GTMAgent.list_tools(registry)) == 1

            # Get tool
            tool = GTMAgent.get_tool(registry, "health_score")
            @test !isnothing(tool)

            # Get tool info
            tool_info = GTMAgent.info(tool)
            @test tool_info.name == "calculate_health_score"
            @test tool_info.category == :customer_success
        end

        @testset "Built-in Tools" begin
            registry = GTMAgent.create_default_registry()
            @test length(GTMAgent.list_tools(registry)) >= 5

            # Test HealthScoreTool
            health_tool = GTMAgent.get_tool(registry, "health_score")
            @test !isnothing(health_tool)

            # Execute health score tool
            ctx = GTMAgent.ToolContext(
                GTMAgent.uuid4(),
                GTMAgent.uuid4(),
                nothing,
                Channel{Bool}(1),
                "test"
            )
            result = GTMAgent.execute(health_tool, Dict{String, Any}("customer_id" => "CUST-001"), ctx)
            @test result.success == true
            @test haskey(result.output, "overall")
        end
    end

    @testset "Provider" begin
        @testset "AnthropicProvider Creation" begin
            # Test provider creation (without API key)
            provider = GTMAgent.AnthropicProvider(api_key="test-key")
            @test provider.model == "claude-sonnet-4-20250514"
            @test provider.api_key == "test-key"
        end

        @testset "Model Info" begin
            provider = GTMAgent.AnthropicProvider(
                api_key="test",
                model="claude-opus-4-20250514"
            )
            info = GTMAgent.model_info(provider)
            @test info.name == "Claude Opus"
            @test info.supports_tools == true
        end
    end

    @testset "Domain Models" begin
        @testset "Customer Stage" begin
            @test GTMAgent.ACTIVE isa GTMAgent.CustomerStage
            @test GTMAgent.AT_RISK isa GTMAgent.CustomerStage
        end

        @testset "Deal Stage" begin
            @test GTMAgent.DISCOVERY isa GTMAgent.DealStage
            @test GTMAgent.CLOSED_WON isa GTMAgent.DealStage
        end
    end

    @testset "Permission System" begin
        @testset "InspectorResult" begin
            approved = GTMAgent.approved()
            @test approved.status == :approved

            denied = GTMAgent.denied("test reason")
            @test denied.status == :denied
            @test denied.reason == "test reason"
        end

        @testset "InspectorPipeline" begin
            config = GTMAgent.PermissionConfig()
            pipeline = GTMAgent.InspectorPipeline(config)
            @test length(pipeline.inspectors) == 4
        end
    end

    @testset "Configuration" begin
        @testset "Config Loading" begin
            config_mgr = GTMAgent.load_config()
            @test !isnothing(config_mgr.merged)

            # Test default values
            agent_name = GTMAgent.get_config(config_mgr, "agent.name", default="unknown")
            @test agent_name == "gtm-agent"
        end

        @testset "Permission Parsing" begin
            @test GTMAgent.parse_permission("allow") == GTMAgent.ALLOW
            @test GTMAgent.parse_permission("deny") == GTMAgent.DENY
            @test GTMAgent.parse_permission("ask") == GTMAgent.ASK
        end
    end

    @testset "Agent" begin
        @testset "Agent Creation" begin
            agent = GTMAgent.GTMAgentInstance()
            @test agent.config.name == "gtm-agent"
            @test agent.running == false
            @test agent.step_count == 0
        end

        @testset "Agent with Config" begin
            config = GTMAgent.AgentConfig(
                name = "test-agent",
                max_steps = 10
            )
            agent = GTMAgent.GTMAgentInstance(config)
            @test agent.config.name == "test-agent"
            @test agent.config.max_steps == 10
        end

        @testset "Agent Reset" begin
            agent = GTMAgent.GTMAgentInstance()
            GTMAgent.add_message!(agent.session.conversation, GTMAgent.user_message("test"))
            @test length(agent.session.conversation.messages) == 1

            GTMAgent.reset!(agent)
            @test length(agent.session.conversation.messages) == 0
        end

        @testset "System Prompt" begin
            agent = GTMAgent.GTMAgentInstance()
            prompt = GTMAgent.get_system_prompt(agent)
            @test contains(prompt, "Go-to-Market")
            @test contains(prompt, "Customer Success")
        end
    end
end

println("\n✅ All tests passed!")
