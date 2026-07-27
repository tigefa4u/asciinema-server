defmodule AsciinemaWeb.ApplicationView do
  import Phoenix.Component, only: [sigil_H: 2]
  alias Asciinema.Accounts

  def present?([]), do: false
  def present?(nil), do: false
  def present?(""), do: false
  def present?(_), do: true

  def time_tag(time) do
    assigns = %{
      iso_8601_ts: Timex.format!(time, "{ISO:Extended:Z}"),
      rfc_1123_ts: Timex.format!(time, "{RFC1123z}")
    }

    ~H|<time datetime={@iso_8601_ts}>on {@rfc_1123_ts}</time>|
  end

  def time_ago_tag(time) do
    assigns = %{
      iso_8601_ts: Timex.format!(time, "{ISO:Extended:Z}"),
      rfc_1123_ts: Timex.format!(time, "{RFC1123z}"),
      from_now: Timex.from_now(time)
    }

    ~H|<time datetime={@iso_8601_ts} title={@rfc_1123_ts}>{@from_now}</time>|
  end

  def pluralize(1, thing), do: "1 #{thing}"
  def pluralize(n, thing), do: "#{n} #{Inflex.pluralize(thing)}"

  def sign_up_enabled?, do: Accounts.sign_up_enabled?()

  def admin_panel_enabled?, do: AsciinemaWeb.Plug.AdminGate.enabled?()

  def safe_json(value) do
    json =
      value
      |> Jason.encode!()
      |> String.replace(~r/</, "\\u003c")

    {:safe, json}
  end

  def render_markdown(input) do
    input = String.trim("#{input}")

    if present?(input) do
      {:safe, HtmlSanitizeEx.basic_html(Earmark.as_html!(input))}
    end
  end
end
