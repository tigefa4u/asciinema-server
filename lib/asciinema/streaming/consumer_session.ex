defmodule Asciinema.Streaming.ConsumerSession do
  # Pure protocol state for one stream consumer (player) connection: event
  # gating, absolute-to-relative time conversion, frame encoding via Alis.V1.

  alias Asciinema.Streaming.Alis

  defstruct init: false, last_event_time: 0.0

  def new, do: %__MODULE__{}

  @doc "Returns {frame_binary | nil, session}"
  def handle_event(session, event, data)

  def handle_event(_session, :reset, data) do
    init(data, term_theme: data[:term_theme], term_init: data[:term_init])
  end

  def handle_event(%__MODULE__{init: false}, :info, data) do
    init(data, term_theme: data.term_theme, term_init: data.term_init)
  end

  def handle_event(%__MODULE__{} = session, :info, _data), do: {nil, session}

  def handle_event(%__MODULE__{init: false} = session, _event, _data), do: {nil, session}

  def handle_event(session, :output, %{id: id, time: time, text: text}) do
    push(session, time, {:output, %{id: id, rel_time: rel_time(session, time), text: text}})
  end

  def handle_event(session, :input, %{id: id, time: time, text: text}) do
    push(session, time, {:input, %{id: id, rel_time: rel_time(session, time), text: text}})
  end

  def handle_event(session, :resize, %{id: id, time: time, term_size: term_size}) do
    push(
      session,
      time,
      {:resize, %{id: id, rel_time: rel_time(session, time), term_size: term_size}}
    )
  end

  def handle_event(session, :marker, %{id: id, time: time, label: label}) do
    push(session, time, {:marker, %{id: id, rel_time: rel_time(session, time), label: label}})
  end

  def handle_event(session, :end, %{time: time}) do
    push(session, time, {:eot, %{rel_time: rel_time(session, time)}})
  end

  defp init(data, opts) do
    frame =
      Alis.V1.encode_frame(
        {:init,
         %{
           last_id: data.last_id,
           time: data.time,
           term_size: data.term_size,
           term_theme: opts[:term_theme],
           term_init: opts[:term_init]
         }}
      )

    {frame, %__MODULE__{init: true, last_event_time: data.time}}
  end

  defp rel_time(session, time), do: time - session.last_event_time

  defp push(session, time, wire_event) do
    {Alis.V1.encode_frame(wire_event), %{session | last_event_time: time}}
  end
end
