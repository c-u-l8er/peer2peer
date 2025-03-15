defmodule IdeaP2pWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use IdeaP2pWeb, :html

  embed_templates "page_html/*"
end
