# Customer domain model for GTM Agent

"""
    CustomerStage

Enum representing customer lifecycle stages.
"""
@enum CustomerStage begin
    PROSPECT
    TRIAL
    ONBOARDING
    ACTIVE
    GROWING
    AT_RISK
    CHURNED
    REACTIVATED
end

"""
    HealthFactor

A factor contributing to customer health score.
"""
struct HealthFactor
    name::String
    score::Float64
    weight::Float64
    trend::Symbol  # :improving, :stable, :declining
    details::String
end

"""
    HealthScore

Customer health score with breakdown.
"""
struct HealthScore
    overall::Float64
    engagement::Float64
    sentiment::Float64
    financial::Float64
    relationship::Float64
    adoption::Float64
    computed_at::DateTime
    factors::Vector{HealthFactor}
end

function HealthScore(;
    overall::Float64,
    engagement::Float64 = 0.0,
    sentiment::Float64 = 0.0,
    financial::Float64 = 0.0,
    relationship::Float64 = 0.0,
    adoption::Float64 = 0.0,
    computed_at::DateTime = now(UTC),
    factors::Vector{HealthFactor} = HealthFactor[]
)
    HealthScore(overall, engagement, sentiment, financial, relationship, adoption, computed_at, factors)
end

"""
    Stakeholder

A stakeholder at a customer organization.
"""
struct Stakeholder
    name::String
    role::String
    email::String
    engagement_level::Symbol  # :high, :medium, :low
    is_champion::Bool
    is_economic_buyer::Bool
end

"""
    Touchpoint

A customer interaction/touchpoint.
"""
struct Touchpoint
    date::DateTime
    type::Symbol  # :meeting, :email, :call, :support_ticket, :qbr
    summary::String
    sentiment::Symbol  # :positive, :neutral, :negative
    participants::Vector{String}
end

"""
    RiskSignal

A risk signal for a customer.
"""
struct RiskSignal
    type::String
    severity::Symbol  # :high, :medium, :low
    description::String
    detected_at::DateTime
    recommended_action::String
end

"""
    ExpansionOpportunity

An expansion opportunity for a customer.
"""
struct ExpansionOpportunity
    type::String  # :upsell, :cross_sell, :seats
    potential_arr::Float64
    probability::Float64
    description::String
    next_steps::Vector{String}
end

"""
    Customer

Complete customer record.
"""
struct Customer
    id::String
    name::String
    stage::CustomerStage
    health::HealthScore
    arr::Float64
    mrr::Float64
    contract_start::Date
    contract_end::Date
    csm::String
    tier::Symbol  # :enterprise, :mid_market, :smb
    industry::String
    use_cases::Vector{String}
    stakeholders::Vector{Stakeholder}
    touchpoints::Vector{Touchpoint}
    risks::Vector{RiskSignal}
    opportunities::Vector{ExpansionOpportunity}
end

"""
    is_at_risk(customer::Customer)

Check if customer is at risk based on health score.
"""
function is_at_risk(customer::Customer)::Bool
    customer.health.overall < 60.0 || customer.stage == AT_RISK
end

"""
    days_to_renewal(customer::Customer)

Calculate days until contract renewal.
"""
function days_to_renewal(customer::Customer)::Int
    Dates.value(customer.contract_end - today())
end

"""
    renewal_urgency(customer::Customer)

Get renewal urgency level.
"""
function renewal_urgency(customer::Customer)::Symbol
    days = days_to_renewal(customer)
    if days <= 30
        :critical
    elseif days <= 60
        :high
    elseif days <= 90
        :medium
    else
        :low
    end
end
