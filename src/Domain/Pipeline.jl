# Pipeline and revenue domain model for GTM Agent

"""
    DealStage

Enum representing deal stages in the pipeline.
"""
@enum DealStage begin
    LEAD
    MQL           # Marketing Qualified Lead
    SQL           # Sales Qualified Lead
    DISCOVERY
    DEMO
    PROPOSAL
    NEGOTIATION
    CLOSED_WON
    CLOSED_LOST
end

"""
    Deal

Sales deal/opportunity record.
"""
struct Deal
    id::String
    account::String
    name::String
    stage::DealStage
    amount::Float64
    probability::Float64
    close_date::Date
    created_date::Date
    owner::String
    source::String
    competitors::Vector{String}
    next_steps::Vector{String}
    risks::Vector{String}
    champion::Union{String, Nothing}
    economic_buyer::Union{String, Nothing}
end

"""
    weighted_value(deal::Deal)

Calculate weighted deal value.
"""
function weighted_value(deal::Deal)::Float64
    deal.amount * deal.probability
end

"""
    is_at_risk(deal::Deal)

Check if deal is at risk.
"""
function is_at_risk(deal::Deal)::Bool
    !isempty(deal.risks) || isnothing(deal.champion)
end

"""
    PipelineMetrics

Aggregated pipeline metrics.
"""
struct PipelineMetrics
    total_pipeline::Float64
    weighted_pipeline::Float64
    stage_distribution::Dict{DealStage, Float64}
    velocity::Float64          # Days to close
    win_rate::Float64
    avg_deal_size::Float64
    coverage_ratio::Float64    # Pipeline / Quota
    deal_count::Int
end

"""
    RevenueMetrics

Revenue and financial metrics.
"""
struct RevenueMetrics
    arr::Float64               # Annual Recurring Revenue
    mrr::Float64               # Monthly Recurring Revenue
    net_retention::Float64     # Net Revenue Retention
    gross_retention::Float64   # Gross Revenue Retention
    expansion_arr::Float64     # Expansion ARR
    churn_arr::Float64         # Churned ARR
    new_arr::Float64           # New business ARR
end

"""
    ForecastEntry

Revenue forecast entry.
"""
struct ForecastEntry
    period::String  # e.g., "Q1 2025"
    committed::Float64
    best_case::Float64
    pipeline::Float64
    target::Float64
    confidence::Float64
end

"""
    Forecast

Revenue forecast with multiple scenarios.
"""
struct Forecast
    generated_at::DateTime
    entries::Vector{ForecastEntry}
    assumptions::Vector{String}
    risks::Vector{String}
    upside_opportunities::Vector{String}
end

"""
    QuotaAttainment

Sales quota attainment tracking.
"""
struct QuotaAttainment
    rep::String
    period::String
    quota::Float64
    attainment::Float64
    percent_to_quota::Float64
    forecast_to_quota::Float64
    rank::Int
    trend::Symbol  # :above_pace, :on_pace, :below_pace
end

"""
    calculate_pipeline_coverage(pipeline::Float64, quota::Float64)

Calculate pipeline coverage ratio.
"""
function calculate_pipeline_coverage(pipeline::Float64, quota::Float64)::Float64
    quota > 0 ? pipeline / quota : 0.0
end

"""
    pipeline_health(coverage::Float64)

Assess pipeline health based on coverage ratio.
"""
function pipeline_health(coverage::Float64)::Symbol
    if coverage >= 4.0
        :healthy
    elseif coverage >= 3.0
        :adequate
    elseif coverage >= 2.0
        :at_risk
    else
        :critical
    end
end
