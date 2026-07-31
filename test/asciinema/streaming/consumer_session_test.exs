defmodule Asciinema.Streaming.ConsumerSessionTest do
  use ExUnit.Case, async: true

  alias Asciinema.Streaming.Alis
  alias Asciinema.Streaming.ConsumerSession

  # Exact frame bytes are owned by the Alis.V1 codec tests, so expected
  # frames here are built with the codec.

  @theme %{fg: {1, 1, 1}, bg: {2, 2, 2}, palette: for(i <- 1..8, do: {i, i, i})}

  defp info_data do
    %{last_id: 3, time: 100, term_size: {80, 24}, term_theme: @theme, term_init: "abc"}
  end

  defp initialized do
    {_frame, session} = ConsumerSession.handle_event(ConsumerSession.new(), :info, info_data())

    session
  end

  test "events before init are dropped" do
    session = ConsumerSession.new()

    assert {nil, ^session} =
             ConsumerSession.handle_event(session, :output, %{id: 1, time: 5, text: "x"})
  end

  test "first info produces an init frame and initializes the session" do
    {frame, session} = ConsumerSession.handle_event(ConsumerSession.new(), :info, info_data())

    assert frame ==
             Alis.V1.encode_frame(
               {:init,
                %{
                  last_id: 3,
                  time: 100,
                  term_size: {80, 24},
                  term_theme: @theme,
                  term_init: "abc"
                }}
             )

    assert session.init
    assert session.last_event_time == 100
  end

  test "subsequent info is ignored" do
    session = initialized()

    assert {nil, ^session} = ConsumerSession.handle_event(session, :info, info_data())
  end

  test "reset re-initializes even when already initialized" do
    session = initialized()
    data = %{last_id: 9, time: 500, term_size: {100, 50}}

    {frame, session} = ConsumerSession.handle_event(session, :reset, data)

    assert frame ==
             Alis.V1.encode_frame(
               {:init,
                %{last_id: 9, time: 500, term_size: {100, 50}, term_theme: nil, term_init: nil}}
             )

    assert session.last_event_time == 500
  end

  test "events after init are encoded with relative times" do
    session = initialized()

    {frame, session} =
      ConsumerSession.handle_event(session, :output, %{id: 4, time: 350, text: "hello"})

    assert frame == Alis.V1.encode_frame({:output, %{id: 4, rel_time: 250, text: "hello"}})
    assert session.last_event_time == 350

    {frame, session} =
      ConsumerSession.handle_event(session, :input, %{id: 5, time: 360, text: "x"})

    assert frame == Alis.V1.encode_frame({:input, %{id: 5, rel_time: 10, text: "x"}})

    {frame, session} =
      ConsumerSession.handle_event(session, :resize, %{id: 6, time: 400, term_size: {90, 30}})

    assert frame ==
             Alis.V1.encode_frame({:resize, %{id: 6, rel_time: 40, term_size: {90, 30}}})

    {frame, session} =
      ConsumerSession.handle_event(session, :marker, %{id: 7, time: 400, label: "ch1"})

    assert frame == Alis.V1.encode_frame({:marker, %{id: 7, rel_time: 0, label: "ch1"}})
    assert session.last_event_time == 400
  end

  test "reset forwards term_theme and term_init when present" do
    data = %{last_id: 9, time: 500, term_size: {100, 50}, term_theme: @theme, term_init: "zz"}

    {frame, _session} = ConsumerSession.handle_event(initialized(), :reset, data)

    assert frame ==
             Alis.V1.encode_frame(
               {:init,
                %{
                  last_id: 9,
                  time: 500,
                  term_size: {100, 50},
                  term_theme: @theme,
                  term_init: "zz"
                }}
             )
  end

  test "negative time delta is passed through unclamped" do
    # Pins current wire behavior: a backwards event time goes through the
    # unsigned LEB128 encoder without clamping (-10 encodes as byte 118).
    # Monotonic clamping is a planned, separately flagged change.
    session = initialized()

    {frame, _session} =
      ConsumerSession.handle_event(session, :output, %{id: 1, time: 90, text: "x"})

    assert frame == <<?o, 1, 118, 1, ?x>>
  end

  test "end produces an EOT frame and keeps the session initialized" do
    session = initialized()

    {frame, session} = ConsumerSession.handle_event(session, :end, %{time: 250})

    assert frame == Alis.V1.encode_frame({:eot, %{rel_time: 150}})

    # Current wire behavior: the session stays initialized after EOT, so a
    # following stream restart is delivered via reset. Gating anomalous
    # events between EOT and reset is a planned, separately flagged change.
    assert session.init

    {frame, _session} =
      ConsumerSession.handle_event(session, :output, %{id: 8, time: 300, text: "y"})

    assert frame == Alis.V1.encode_frame({:output, %{id: 8, rel_time: 50, text: "y"}})
  end
end
