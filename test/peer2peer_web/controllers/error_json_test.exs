defmodule Peer2peerWeb.ErrorJSONTest do
  use Peer2peerWeb.ConnCase, async: true

  test "renders 404" do
    assert Peer2peerWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert Peer2peerWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
