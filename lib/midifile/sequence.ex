defmodule Midifile.Sequence do

  defstruct header: nil,
    conductor_track: nil,
    tracks: {}

  def name(%Midifile.Sequence{conductor_track: nil}), do: ""
  def name(%Midifile.Sequence{conductor_track: %Midifile.Track{events: {}}}),  do: ""
  def name(%Midifile.Sequence{conductor_track: %Midifile.Track{events: list}})  do
    Enum.find(list, %Midifile.Event{}, &(&1.symbol == :seq_name)).bytes
  end

end
