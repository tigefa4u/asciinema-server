defmodule Asciinema.Workers.MarkOfflineStreamsTest do
  use Asciinema.DataCase, async: true
  use Oban.Testing, repo: Asciinema.Repo

  import Asciinema.Factory

  alias Asciinema.Streaming
  alias Asciinema.Workers.MarkOfflineStreams

  describe "perform/1" do
    test "marks inactive streams offline once past the startup grace period" do
      put_grace_period(0)

      stream =
        insert(:stream, live: true, last_activity_at: DateTime.add(DateTime.utc_now(), -300))

      assert perform_job(MarkOfflineStreams, %{}) == :ok

      refute Streaming.get_stream(stream.id).live
    end

    test "does nothing within the startup grace period" do
      put_grace_period(1_000_000)

      stream =
        insert(:stream, live: true, last_activity_at: DateTime.add(DateTime.utc_now(), -300))

      assert perform_job(MarkOfflineStreams, %{}) == :ok

      assert Streaming.get_stream(stream.id).live
    end
  end

  defp put_grace_period(seconds) do
    original = Application.get_env(:asciinema, MarkOfflineStreams)
    Application.put_env(:asciinema, MarkOfflineStreams, grace_period: seconds)

    on_exit(fn ->
      if original do
        Application.put_env(:asciinema, MarkOfflineStreams, original)
      else
        Application.delete_env(:asciinema, MarkOfflineStreams)
      end
    end)
  end
end
