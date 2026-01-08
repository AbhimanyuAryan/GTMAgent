# Market intelligence domain model for GTM Agent

"""
    NewsItem

A news item about a company or market.
"""
struct NewsItem
    title::String
    source::String
    date::Date
    summary::String
    url::String
    sentiment::Symbol  # :positive, :neutral, :negative
end

"""
    BattleCard

Competitive battle card for sales enablement.
"""
struct BattleCard
    competitor::String
    scenario::String
    customer_objection::String
    response::String
    proof_points::Vector{String}
    updated_at::DateTime
end

"""
    Competitor

Competitor analysis record.
"""
struct Competitor
    name::String
    description::String
    positioning::String
    strengths::Vector{String}
    weaknesses::Vector{String}
    pricing_model::String
    target_segments::Vector{String}
    recent_news::Vector{NewsItem}
    battle_cards::Vector{BattleCard}
end

"""
    ICP

Ideal Customer Profile definition.
"""
struct ICP
    company_size::UnitRange{Int}
    industries::Vector{String}
    geographies::Vector{String}
    technologies::Vector{String}
    pain_points::Vector{String}
    buying_triggers::Vector{String}
    decision_makers::Vector{String}
    budget_range::Tuple{Float64, Float64}
end

"""
    MarketSegment

Market segment definition with sizing.
"""
struct MarketSegment
    name::String
    tam::Float64  # Total Addressable Market
    sam::Float64  # Serviceable Addressable Market
    som::Float64  # Serviceable Obtainable Market
    growth_rate::Float64
    key_drivers::Vector{String}
    challenges::Vector{String}
    ideal_customer_profile::ICP
end

"""
    WinLossRecord

Win/loss analysis record.
"""
struct WinLossRecord
    deal_name::String
    customer::String
    outcome::Symbol  # :won, :lost, :no_decision
    amount::Float64
    competitor::Union{String, Nothing}
    primary_reason::String
    secondary_reasons::Vector{String}
    lessons_learned::Vector{String}
    date::Date
end

"""
    MarketTrend

Market trend data.
"""
struct MarketTrend
    name::String
    category::Symbol  # :technology, :regulatory, :economic, :competitive
    impact::Symbol    # :positive, :negative, :neutral
    description::String
    implications::Vector{String}
    time_horizon::Symbol  # :short_term, :medium_term, :long_term
end
