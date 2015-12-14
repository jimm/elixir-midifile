defmodule SequenceTest do
  use ExUnit.Case
  alias Midifile.Sequence
  alias Midifile.Track
  alias Midifile.Event

  setup do
    e = %Event{symbol: :on, delta_time: 100, bytes: [0x92, 64, 127]}
    t = %Track{events: [e, e, e]}
    ct = %Track{events: [%Event{symbol: :seq_name, bytes: "Unnamed"}]}
    {:ok, %{seq: %Sequence{division: 480, conductor_track: ct, tracks: [t, t, t]},
            track: t}}
  end

  test "name", context do
    assert Sequence.name(context[:seq]) == "Unnamed"
  end

  test "ppqn", context do
    assert Sequence.ppqn(context[:seq]) == 480
  end
end
