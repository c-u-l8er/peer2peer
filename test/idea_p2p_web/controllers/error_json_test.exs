defmodule IdeaP2pWeb.ErrorJSONTest do
  use IdeaP2pWeb.ConnCase, async: true

  test "renders 404" do
    assert IdeaP2pWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert IdeaP2pWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
