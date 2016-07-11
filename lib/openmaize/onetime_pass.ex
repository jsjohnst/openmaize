defmodule Openmaize.OnetimePass do
  @moduledoc """
  Module to handle one-time passwords for use in two factor authentication.

  There is one option:

    * db_module - the module that is used to query the database
      * in most cases, this will be generated by `mix openmaize.gen.ectodb` and will be called MyApp.OpenmaizeEcto
      * if you implement your own database module, it needs to implement the Openmaize.Database behaviour

      ALSO OPTIONS FOR OTP
  """

  import Plug.Conn
  alias Comeonin.Otp

  @behaviour Plug

  def init(opts) do
    Keyword.pop opts, :db_module
  end

  @doc """
  Handle the one-time password POST request.

  If the one-time password check is successful, the user will be added
  to the session.
  """
  def call(_, {nil, _}) do
    raise ArgumentError, "You need to set the db_module value for Openmaize.OnetimePass"
  end
  def call(%Plug.Conn{params: %{"user" => %{"id" => id} = user_params}} = conn,
   {db_module, opts}) do
    db_module.find_user_byid(id)
    |> check_key(user_params, opts)
    |> handle_auth(conn)
  end

  defp check_key(user, %{"hotp" => hotp}, opts) do
    {user, Otp.check_hotp(hotp, user.otp_secret, opts)}
  end
  defp check_key(user, %{"totp" => totp}, opts) do
    {user, Otp.check_totp(totp, user.otp_secret, opts)}
  end

  defp handle_auth({_, false}, conn) do
    put_private(conn, :openmaize_error, "Invalid credentials")
  end
  defp handle_auth({user, last}, conn) do
    conn
    |> put_private(:openmaize_info, last)
    |> put_session(:user_id, user.id)
  end
end
