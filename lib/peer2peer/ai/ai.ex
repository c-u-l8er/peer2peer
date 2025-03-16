defmodule Peer2peer.AI do
  @moduledoc """
  AI integration module for connecting to external AI services.
  Supports multiple providers and handles API communication.
  """

  require Logger

  # Get configuration
  def config do
    Application.get_env(:peer2peer, __MODULE__, [])
  end

  def default_provider do
    providers = config()[:providers] || [:openai]
    config()[:default_provider] || List.first(providers)
  end

  @doc """
  Generate a response from the AI using the specified provider
  """
  def generate_response(messages, opts \\ []) do
    provider = Keyword.get(opts, :provider, default_provider())
    provider_config = config()[provider] || []

    api_key = get_api_key(provider, provider_config)
    model = Keyword.get(opts, :model) || provider_config[:default_model]

    case provider do
      :openai -> generate_openai_response(messages, api_key, model, opts)
      :anthropic -> generate_anthropic_response(messages, api_key, model, opts)
      _ -> {:error, "Unsupported AI provider: #{provider}"}
    end
  end

  defp get_api_key(provider, provider_config) do
    case provider_config[:api_key] do
      {:system, env_var} -> System.get_env(env_var)
      key when is_binary(key) -> key
      _ -> nil
    end
  end

  defp generate_openai_response(messages, api_key, model, opts) do
    # For now, a simple mock implementation
    # In a real implementation, this would make API calls to OpenAI
    Logger.info("Generating OpenAI response with model: #{model}")

    # Simulate API call delay
    Process.sleep(500)

    {:ok,
     %{
       content: "This is a simulated response from OpenAI's #{model}.",
       model: model,
       provider: :openai
     }}
  end

  defp generate_anthropic_response(messages, api_key, model, opts) do
    # For now, a simple mock implementation
    # In a real implementation, this would make API calls to Anthropic
    Logger.info("Generating Anthropic response with model: #{model}")

    # Simulate API call delay
    Process.sleep(700)

    {:ok,
     %{
       content: "This is a simulated response from Anthropic's #{model}.",
       model: model,
       provider: :anthropic
     }}
  end
end
