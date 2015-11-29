defmodule TrackTest do
  use ExUnit.Case
  alias Midifile.Sequence
  alias Midifile.Track
  alias Midifile.Event

  setup do
    e = %Event{symbol: :on, delta_time: 100, bytes: [0x92, 64, 127]}
    t = %Track{events: [e, e, e]}
    {:ok, %{seq: %Sequence{tracks: [t, t, t]}, track: t}}
  end

  test "basics", context do
    assert length(context[:seq].tracks) == 3
    assert(context[:track].name, "Unnamed")
  end

  test "start times", context do
    assert Track.start_times(context[:track]) == [100, 200, 300]
  end

  test "quantize", context do
    t = Track.quantize(context[:track], 80)
    assert Track.start_times(t) == [80, 240, 320]
    deltas = t.events |> Enum.map(&(&1.delta_time))
    assert deltas == [80, 160, 80]
  end
end
