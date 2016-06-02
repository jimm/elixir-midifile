defmodule Midifile.Track do

  alias Midifile.Event

  defstruct name: "Unnamed",
    events: []

  def instrument(%Midifile.Track{events: nil}), do: ""
  def instrument(%Midifile.Track{events: {}}),  do: ""
  def instrument(%Midifile.Track{events: list})  do
    Enum.find(list, %Event{}, &(&1.symbol == :instrument)).bytes
  end

  def quantize(track, n) do
    %{track | events: Event.quantize(track.events, n)}
  end
end
