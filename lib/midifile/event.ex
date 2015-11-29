defmodule Midifile.Event do
  use Bitwise

  defstruct symbol: :off,
    delta_time: 0,
    bytes: []                   # data bytes, including status byte

  def status(%Midifile.Event{bytes: [st|_]}) when st < 0xf0 do
    band(st, 0xf0)
  end
  def status(%Midifile.Event{bytes: [st|_]}) do
    st
  end

  def data(%Midifile.Event{bytes: [_|data]}), do: data

  def channel?(%Midifile.Event{bytes: [st|_]}) when st < 0xf0, do: true
  def channel?(_), do: false

  def note?(%Midifile.Event{bytes: [st|_]}) when st < 0xb0, do: true
  def note?(_), do: false

  def channel(%Midifile.Event{bytes: [st|_]}) when st < 0xf0 do
    band(st, 0x0f)
  end

  def note(%Midifile.Event{bytes: [st, n, _]}) when st < 0xb0 do
    n
  end

  def velocity(%Midifile.Event{bytes: [st, _, v]}) when st < 0xb0 do
    v
  end

  # Quantize an event `e`'s time_from_start by moving it to the nearest
  # multiple of `n`. See `Midifile.Track#quantize`. _Note_: does not modify
  # the event's delta_time, though `Midifile.Track#quantize` calls
  # `recalc_delta_from_times` after it asks each event to quantize itself.
  def quantize(e, prev_delta, n) do
    time_from_start = prev_delta + e.delta_time
    modulo = rem(time_from_start, n)
    new_time_from_start = if modulo >= n / 2 do
      time_from_start + n - modulo
    else
      time_from_start - modulo
    end
    %{e | delta_time: new_time_from_start - prev_delta}
  end

  def to_string(%Midifile.Event{bytes: [st|data]} = e) do
    "#{e.delta_time}: ch #{band(st, 0x0f)} #{e.symbol} #{inspect data}"
  end
end
