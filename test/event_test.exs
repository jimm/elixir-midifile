defmodule EventTest do
  use ExUnit.Case, async: true
  alias Midifile.Event

  test "channel?" do
    e = %Event{symbol: :on, bytes: [0x92, 64, 127]}
    assert(Event.channel?(e))
    e = %Event{symbol: :on, bytes: [0xff, 64, 127]} 
    assert(!Event.channel?(e))
  end

  test "note?" do
    e = %Event{symbol: :on, bytes: [0xa2, 64, 127]}
    assert(Event.note?(e))
    e = %Event{symbol: :on, bytes: [0xb2, 64, 127]} 
    assert(!Event.note?(e))
  end

  test "status" do
    e = %Event{bytes: [0x92, 64, 127]}
    assert(Event.status(e) == 0x90)
    e = %Event{bytes: [0xff, 64, 127]}
    assert(Event.status(e) == 0xff)
  end

  test "data" do
    e = %Event{bytes: [0x92, 64, 127]}
    assert(Event.data(e) == [64, 127])
  end

  test "channel" do
    e = %Event{bytes: [0x92, 64, 127]}
    assert(Event.channel(e) == 0x02)
    e = %Event{bytes: [0xff, 64, 127]}
    catch_error(Event.channel(e))
  end

  test "note" do
    e = %Event{bytes: [0x92, 64, 127]}
    assert(Event.note(e) == 64)
    e = %Event{bytes: [0xff, 64, 127]}
    catch_error(Event.note(e))
  end

  test "velocity" do
    e = %Event{bytes: [0x92, 64, 127]}
    assert(Event.velocity(e) == 127)
    e = %Event{bytes: [0xff, 64, 127]}
    catch_error(Event.velocity(e))
  end

  test "note on" do
    e = %Event{symbol: :on, bytes: [0x92, 64, 127]}
    assert(Event.status(e) == 0x90)
    assert(Event.channel(e) == 2)
    assert(Event.note(e) == 64)
    assert(Event.velocity(e) == 127)
  end

  test "to_string" do
    e = %Event{symbol: :on, bytes: [0x90, 64, 127]}
    assert "0: ch 0 on [64, 127]" = Event.to_string(e)
  end

  test "start times" do
    events = [100, 100, 100] |> Enum.map(fn dt -> %Event{delta_time: dt} end)
    assert [100, 200, 300] = Event.start_times(events)
  end

  test "delta times" do
    start_times = [100, 200, 350]
    assert [100, 100, 150] = Event.delta_times(start_times)
  end

  test "merge" do
    e = %Event{symbol: :on, delta_time: 100, bytes: [0x92, 64, 127]}
    es1 = [e, e, e]

    es2 = (1..5)
    |> Enum.map(fn(_) -> %Event{delta_time: 30, bytes: [0x80, 64, 127]} end)

    events = Event.merge(es1, es2)
    assert [30, 60, 90, 100, 120, 150, 200, 300] = Event.start_times(events)
    statuses = events |> Enum.map(&(Event.status(&1)))
    assert [0x80, 0x80, 0x80, 0x90, 0x80, 0x80, 0x90, 0x90] = statuses
  end

  test "quantize_to" do
    [{80, 79, 80},
     {80, 481, 480},
     {4, 5, 4},
     {4, 0, 0},
     {4, 5, 4},
     {4, 6, 8}]
    |> Enum.map(fn {q, t, expected} ->
      assert expected == Event.quantize_to(t, q)
    end)
  end

  test "quantize 4" do
    # Each value in this array is the expected quantized start time of its
    # index in the array.
    expected = [0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12, 16]

    events = [%Event{delta_time: 0} | tl(expected)
              |> Enum.map(fn _ -> %Event{delta_time: 1} end)]
    # sanity checks
    assert [0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1] = delta_times(events)
    assert [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14] = Event.start_times(events)

    quantized = Event.quantize(events, 4)
    assert expected == quantized |> Event.start_times
  end

  test "quantize 6" do
    expected = [0, 0, 0, 6, 6, 6, 6, 6, 6, 12, 12, 12, 12, 12, 12, 18, 18]
    events = [%Event{delta_time: 0} | tl(expected)
              |> Enum.map(fn _ -> %Event{delta_time: 1} end)]
    quantized = Event.quantize(events, 6)
    assert expected == quantized |> Event.start_times
  end

  test "quantize 80" do
    # {orig_delta, expected_delta}
    vals = [{0, 0},
            {1, 0},
            {70, 80},
            {100, 80},
            {398, 400},
            {405, 400},
            {440, 480},
            {441, 400}]
    expected = vals |> Enum.map(fn({_, exp}) -> %Event{delta_time: exp} end)
    events = vals |> Enum.map(fn({orig, _}) -> %Event{delta_time: orig} end)
    quantized = Event.quantize(events, 80)
    assert delta_times(expected) == delta_times(quantized)
  end

  # Return delta times
  defp delta_times(events) do
    events |> Enum.map(fn e -> e.delta_time end)
  end
end
