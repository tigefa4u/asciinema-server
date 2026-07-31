defmodule Asciinema.Streaming.Alis.V1Test do
  use ExUnit.Case, async: true

  alias Asciinema.Streaming.Alis

  # All expected values are literal golden bytes, computed by hand from the
  # ALIS v1 spec - not roundtripped through our own decoder.

  test "magic string" do
    assert Alis.V1.magic() == <<65, 76, 105, 83, 1>>
  end

  describe "init frame" do
    test "without theme and term_init" do
      frame = Alis.V1.encode_frame({:init, %{last_id: 5, time: 100, term_size: {80, 24}}})

      assert frame == <<1, 5, 100, 80, 24, 0, 0>>
    end

    test "with multi-byte varints, 8-color theme and term_init" do
      theme = %{
        fg: {1, 2, 3},
        bg: {4, 5, 6},
        palette: for(i <- 10..17, do: {i, i, i})
      }

      frame =
        Alis.V1.encode_frame(
          {:init,
           %{
             last_id: 300,
             time: 16_384,
             term_size: {80, 24},
             term_theme: theme,
             term_init: "ab"
           }}
        )

      palette_bytes = for i <- 10..17, into: <<>>, do: <<i, i, i>>

      assert frame ==
               <<1, 172, 2, 128, 128, 1, 80, 24, 8, 1, 2, 3, 4, 5, 6>> <>
                 palette_bytes <> <<2, ?a, ?b>>
    end

    test "with 16-color theme" do
      theme = %{
        fg: {0, 0, 0},
        bg: {255, 255, 255},
        palette: for(i <- 1..16, do: {i, 0, 0})
      }

      frame =
        Alis.V1.encode_frame(
          {:init, %{last_id: 0, time: 0, term_size: {1, 1}, term_theme: theme}}
        )

      palette_bytes = for i <- 1..16, into: <<>>, do: <<i, 0, 0>>

      assert frame == <<1, 0, 0, 1, 1, 16, 0, 0, 0, 255, 255, 255>> <> palette_bytes <> <<0>>
    end

    test "crashes on a palette that is not 8 or 16 colors" do
      theme = %{fg: {0, 0, 0}, bg: {0, 0, 0}, palette: [{1, 1, 1}]}

      assert_raise MatchError, fn ->
        Alis.V1.encode_frame(
          {:init, %{last_id: 0, time: 0, term_size: {1, 1}, term_theme: theme}}
        )
      end
    end
  end

  describe "event frames" do
    test "output" do
      frame = Alis.V1.encode_frame({:output, %{id: 2, rel_time: 300, text: "hello"}})

      assert frame == <<?o, 2, 172, 2, 5>> <> "hello"
    end

    test "output with multi-byte UTF-8 text uses byte length" do
      frame = Alis.V1.encode_frame({:output, %{id: 1, rel_time: 0, text: "żółć"}})

      assert frame == <<?o, 1, 0, 8, 197, 188, 195, 179, 197, 130, 196, 135>>
    end

    test "input" do
      frame = Alis.V1.encode_frame({:input, %{id: 7, rel_time: 1, text: ""}})

      assert frame == <<?i, 7, 1, 0>>
    end

    test "resize" do
      frame = Alis.V1.encode_frame({:resize, %{id: 3, rel_time: 0, term_size: {100, 50}}})

      assert frame == <<?r, 3, 0, 100, 50>>
    end

    test "marker with varint boundary values" do
      assert Alis.V1.encode_frame({:marker, %{id: 4, rel_time: 16_383, label: ""}}) ==
               <<?m, 4, 255, 127, 0>>

      assert Alis.V1.encode_frame({:marker, %{id: 4, rel_time: 16_384, label: "x"}}) ==
               <<?m, 4, 128, 128, 1, 1, ?x>>
    end

    test "eot is ID-less" do
      assert Alis.V1.encode_frame({:eot, %{rel_time: 100}}) == <<4, 100>>
    end
  end
end
