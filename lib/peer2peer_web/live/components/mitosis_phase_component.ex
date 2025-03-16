defmodule Peer2peerWeb.MitosisPhaseComponent do
  use Peer2peerWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="mitosis-phase-indicator">
      <div class="text-sm font-semibold mb-1">Conversation Phase</div>
      <div class="flex items-center space-x-1">
        <div
          class={"phase-dot #{if phase_active?(:prophase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("prophase-info")}
        >
          <div class="phase-label">Prophase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:prometaphase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("prometaphase-info")}
        >
          <div class="phase-label">Prometaphase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:metaphase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("metaphase-info")}
        >
          <div class="phase-label">Metaphase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:anaphase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("anaphase-info")}
        >
          <div class="phase-label">Anaphase</div>
        </div>
        <div class="phase-line"></div>
        <div
          class={"phase-dot #{if phase_active?(:telophase, @phase), do: 'active', else: ''}"}
          phx-click={@show_info && show_modal("telophase-info")}
        >
          <div class="phase-label">Telophase</div>
        </div>
      </div>

      <div class="mt-2 progress-bar">
        <div class="progress-fill" style={"width: #{@progress * 100}%"}></div>
      </div>

      <div :if={@show_help} class="mt-2 text-xs text-gray-500 italic">
        Click on a phase to learn more about it
      </div>

      <%= if @show_info do %>
        <.modal id="prophase-info">
          <h3 class="text-lg font-semibold mb-2">Prophase</h3>
          <p>
            Initial ideas are organized and structured. This is where conversations begin and participants start sharing their thoughts.
          </p>
        </.modal>

        <.modal id="prometaphase-info">
          <h3 class="text-lg font-semibold mb-2">Prometaphase</h3>
          <p>
            Barriers between topics and users break down. Ideas begin to flow more freely and connections form between different concepts.
          </p>
        </.modal>

        <.modal id="metaphase-info">
          <h3 class="text-lg font-semibold mb-2">Metaphase</h3>
          <p>
            Ideas align and reach consensus. The key concepts and points of agreement become clear to all participants.
          </p>
        </.modal>

        <.modal id="anaphase-info">
          <h3 class="text-lg font-semibold mb-2">Anaphase</h3>
          <p>
            Conversation begins splitting into separate threads. Distinct topics emerge that may benefit from focused discussion.
          </p>
        </.modal>

        <.modal id="telophase-info">
          <h3 class="text-lg font-semibold mb-2">Telophase</h3>
          <p>
            Complete separation into new conversation groups. The original conversation divides into multiple related conversations, each focused on a specific aspect.
          </p>
        </.modal>
      <% end %>
    </div>
    """
  end

  defp phase_active?(phase, current_phase) do
    # Map phases to their order for comparison
    phase_order = %{
      prophase: 1,
      prometaphase: 2,
      metaphase: 3,
      anaphase: 4,
      telophase: 5
    }

    # A phase is active if it's the current phase or comes before it
    phase_order[phase] <= phase_order[current_phase]
  end
end
