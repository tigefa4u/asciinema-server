defmodule Asciinema.Streaming.Alis.V1 do
  # The ALIS v1 wire format (https://docs.asciinema.org/manual/server/streaming/).
  #
  # Single home for the binary layout of ALIS frames. Encoding (server ->
  # player) lives here; decoding (CLI -> server) still lives in
  # Asciinema.Streaming.Parser.AlisV1 and moves here in a follow-up.
  #
  # Frames take relative times (rel_time) - converting from the absolute
  # times used elsewhere in the app is the caller's job.
  #
  # Inputs come from our own stream state, not from the wire, so invalid
  # input crashes via pattern match instead of returning errors.

  alias Asciinema.Leb128

  def magic, do: "ALiS\x01"

  def encode_frame({:init, %{last_id: id, time: time, term_size: {cols, rows}} = data}) do
    <<1::8>> <>
      varint(id) <>
      varint(time) <>
      varint(cols) <>
      varint(rows) <>
      encode_theme(data[:term_theme]) <>
      encode_string(data[:term_init] || "")
  end

  def encode_frame({:output, %{id: id, rel_time: time, text: text}}) do
    <<?o>> <> varint(id) <> varint(time) <> encode_string(text)
  end

  def encode_frame({:input, %{id: id, rel_time: time, text: text}}) do
    <<?i>> <> varint(id) <> varint(time) <> encode_string(text)
  end

  def encode_frame({:resize, %{id: id, rel_time: time, term_size: {cols, rows}}}) do
    <<?r>> <> varint(id) <> varint(time) <> varint(cols) <> varint(rows)
  end

  def encode_frame({:marker, %{id: id, rel_time: time, label: label}}) do
    <<?m>> <> varint(id) <> varint(time) <> encode_string(label)
  end

  # EOT is ID-less, as documented; the producer-side parser currently expects
  # a legacy id + time form - see the follow-up note above.
  def encode_frame({:eot, %{rel_time: time}}) do
    <<0x04::8>> <> varint(time)
  end

  defp varint(value), do: Leb128.encode(value)

  defp encode_string(text), do: varint(byte_size(text)) <> text

  defp encode_theme(nil), do: <<0::8>>

  defp encode_theme(theme) do
    format = length(theme.palette)
    true = format in [8, 16]

    colors =
      for {r, g, b} <- [theme.fg, theme.bg | theme.palette], into: <<>> do
        <<r::8, g::8, b::8>>
      end

    <<format::8>> <> colors
  end
end
