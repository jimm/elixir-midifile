defmodule TrackTest do
  use ExUnit.Case, async: true
  alias Midifile.Sequence
  alias Midifile.Track
  alias Midifile.Event

  setup do
    e = %Event{symbol: :on, delta_time: 100, bytes: [0x92, 64, 127]}
    t = %Track{events: [e, e, e]}
    {:ok, %{seq: %Sequence{tracks: [t, t, t]}, track: t}}
  end

  test "basics", context do
    assert 3 = length(context[:seq].tracks)
    assert(context[:track].name, "Unnamed")
  end

  test "quantize", context do
    t = Track.quantize(context[:track], 80)
    assert [80, 240, 320] = t.events |> Event.start_times
    deltas = t.events |> Enum.map(&(&1.delta_time))
    assert [80, 160, 80] = deltas
  end
end
