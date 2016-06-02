defmodule Midifile.Event do
  use Bitwise

  defstruct symbol: :off,
    delta_time: 0,
    bytes: []                   # data bytes, including status byte

  def status(%Midifile.Event{bytes: [st|_]}) when st < 0xf0, do: band(st, 0xf0)
  def status(%Midifile.Event{bytes: [st|_]}), do: st

  def data(%Midifile.Event{bytes: [_|data]}), do: data

  def channel?(%Midifile.Event{bytes: [st|_]}) when st < 0xf0, do: true
  def channel?(_), do: false

  def note?(%Midifile.Event{bytes: [st|_]}) when st < 0xb0, do: true
  def note?(_), do: false

  def channel(%Midifile.Event{bytes: [st|_]}) when st < 0xf0, do: band(st, 0x0f)

  def note(%Midifile.Event{bytes: [st, n, _]}) when st < 0xb0, do: n

  def velocity(%Midifile.Event{bytes: [st, _, v]}) when st < 0xb0, do: v

  @doc """
  Returns a list of start times (not delta times) of each event.
  """
  def start_times(events) do
    {_, start_times} = events
    |> Enum.reduce({0, []}, fn(e, {prev_delta, sts}) ->
      {prev_delta + e.delta_time, [prev_delta + e.delta_time | sts]}
    end)
    Enum.reverse(start_times)
  end

  @doc """
  Given a list of start times, returns a list of delta times.
  """
  def delta_times(sts) do
    {_, deltas} = sts
    |> Enum.reduce({0, []}, fn(start_time, {prev_start_time, deltas}) ->
      {start_time, [start_time - prev_start_time | deltas]}
    end)
    Enum.reverse(deltas)
  end

  # Return a list of events where every event has been quantized.
  # We quantize start times, then convert back to deltas.
  def quantize(events, n) do
    quantized_delta_times = events
    |> start_times
    |> Enum.map(&quantize_to(&1, n))
    |> delta_times

    Enum.zip(events, quantized_delta_times)
    |> Enum.map(fn({e, t}) -> %{e | delta_time: t} end)
  end

  def quantize_to(t, n) do
    modulo = rem(t, n)
    if modulo >= n / 2 do
      t + n - modulo
    else
      t - modulo
    end
  end

  @doc """
  Merges two lists of events in the proper order.
  """
  def merge(es1, es2) do
    merged = [Enum.zip(es1, start_times(es1)),
              Enum.zip(es2, start_times(es2))]
    |> Enum.concat
    |> Enum.sort(fn({_, start1}, {_, start2}) -> start1 < start2 end)

    {_, es} = merged
    |> Enum.reduce({0, []}, fn({e, start}, {prev_start_time, es2}) ->
      delta = start - prev_start_time
      {start, [%{e | delta_time: delta} | es2]}
    end)

    Enum.reverse(es)
  end

  def to_string(%Midifile.Event{bytes: [st|data]} = e) do
    "#{e.delta_time}: ch #{band(st, 0x0f)} #{e.symbol} #{inspect data}"
  end
end
