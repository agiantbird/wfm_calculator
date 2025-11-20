module ApplicationHelper
  # Calculate minimum number of agents needed for Erlang C model
  def calculate_erlang_agents(traffic_intensity, service_level_target, target_time, aht)
    # Start with minimum agents = ceiling of traffic intensity
    agents = traffic_intensity.ceil
    max_agents = (traffic_intensity * 3).ceil  # Safety limit

    # Iterate to find minimum agents that meet service level
    while agents <= max_agents
      service_level = calculate_service_level(traffic_intensity, agents, target_time, aht)

      if service_level >= service_level_target
        return agents
      end

      agents += 1
    end

    # If we couldn't find a solution, return the max we tried
    agents
  end

  # Calculate service level for given parameters
  def calculate_service_level(traffic_intensity, agents, target_time, aht)
    # Calculate Erlang C (probability of delay)
    prob_delay = erlang_c(traffic_intensity, agents)

    # Calculate probability call is answered within target time
    # Formula: 1 - (Prob_Delay * e^(-(agents - traffic) * target_time / AHT))
    agent_surplus = agents - traffic_intensity
    return 0.0 if agent_surplus <= 0

    exponential_term = Math.exp(-(agent_surplus * target_time) / aht)
    service_level = 1.0 - (prob_delay * exponential_term)

    service_level
  end

  # Erlang C formula: probability of delay
  def erlang_c(traffic_intensity, agents)
    return 1.0 if agents <= traffic_intensity

    # Calculate Erlang B first
    erlang_b = erlang_b_value(traffic_intensity, agents)

    # Erlang C formula
    numerator = agents * erlang_b
    denominator = agents - traffic_intensity * (1 - erlang_b)

    return 0.0 if denominator <= 0

    numerator / denominator
  end

  # Calculate Erlang B (used in Erlang C calculation)
  def erlang_b_value(traffic_intensity, agents)
    return 1.0 if agents == 0

    erlang_b = 1.0

    (1..agents).each do |n|
      erlang_b = (traffic_intensity * erlang_b) / (n + traffic_intensity * erlang_b)
    end

    erlang_b
  end
end
