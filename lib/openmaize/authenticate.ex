defmodule Openmaize.Authenticate do
  @moduledoc """
  Module to authenticate users.

  JSON Web Tokens (JWTs) are used to authenticate the user.
  If there is no token or the token is invalid, the user will
  be redirected to the login page.

  """

  import Plug.Conn
  import Openmaize.Tools
  alias Openmaize.Config
  alias Openmaize.Login
  alias Openmaize.Logout
  alias Openmaize.Token

  @behaviour Plug

  def init(opts), do: opts

  @doc """
  Function to check the token provided. If there is no token, or if the
  token is invalid, the user is redirected to the login page.

  If the path is for the login or logout page, the user is redirected
  to that page straight away.
  """
  def call(%{path_info: path_info} = conn, _opts) do
    case Enum.at(path_info, -1) do
      "login" -> handle_login(conn)
      "logout" -> handle_logout(conn)
      _ -> handle_auth(conn, Config.storage_method)
    end
  end

  defp handle_login(%{method: "POST"} = conn), do: Login.call(conn, [])
  defp handle_login(conn), do: assign(conn, :current_user, nil)

  defp handle_logout(conn), do: assign(conn, :current_user, nil) |> Logout.call([])

  defp handle_auth(conn, storage) when storage == "cookie" do
    conn = fetch_cookies(conn)
    Map.get(conn.req_cookies, "access_token") |> check_token(conn)
  end
  defp handle_auth(conn, _storage) do
    get_req_header(conn, "authorization") |> check_token(conn)
  end

  defp check_token(["Bearer " <> token], conn), do: check_token(token, conn)
  defp check_token(token, conn) when is_binary(token) do
    case Token.decode(token) do
      {:ok, data} -> verify_user(conn, data)
      {:error, message} -> redirect_to_login(conn, %{"error" => message})
    end
  end
  defp check_token(_, %{path_info: path_info} = conn) do
    if Enum.at(path_info, 0) in Config.protected do
      redirect_to_login(conn, %{})
    else
      assign(conn, :current_user, nil)
    end
  end

  defp verify_user(conn, data) do
    assign(conn, :current_user, data)
  end

end
