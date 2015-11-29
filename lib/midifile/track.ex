defmodule Midifile.Track do

  alias Midifile.Event

  defstruct name: "Unnamed",
    events: []

  def instrument(%Midifile.Track{events: nil}), do: ""
  def instrument(%Midifile.Track{events: {}}),  do: ""
  def instrument(%Midifile.Track{events: list})  do
    Enum.find(list, %Event{}, &(&1.symbol == :instrument)).bytes
  end

  # Merges a list of `events` into `track`'s event list in the proper time
  # order and returns a new track with the combined events.
  def merge(_track, _events) do
    # TODO
  end

  # Return a track where every event in `track` has been quantized.
  def quantize(track, n) do
    {_, new_deltas} = start_times(track)
    |> Enum.map(&quantize_to(&1, n))
    |> Enum.reduce({0, []}, fn(start_at, {prev, times}) ->
      {start_at, [start_at - prev | times]}
    end)

    es = Enum.zip(track.events, Enum.reverse(new_deltas))
    |> Enum.map(fn({e, t}) -> %{e | delta_time: t} end)

    %{track | events: es}
  end

  defp quantize_to(t, n) do
    modulo = rem(t, n)
    if modulo >= n / 2 do
      t + n - modulo
    else
      t - modulo
    end
  end

  def start_times(track) do
    {_, start_times} = track.events |>
    Enum.reduce({0, []}, fn(e, {prev_delta, sts}) ->
      {prev_delta + e.delta_time, [prev_delta + e.delta_time | sts]}
    end)
    Enum.reverse(start_times)
  end
end
