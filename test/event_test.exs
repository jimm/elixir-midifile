defmodule EventTest do
  use ExUnit.Case
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
    assert(Event.to_string(e) == "0: ch 0 on [64, 127]")
  end

  test "quantize 1" do
    # Each value in this array is the expected quantized value of
    # its index in the array.

    # Test with quantize(4)
    [0, 0, 4, 4, 4, 4, 8, 8, 8, 8, 12, 12, 12, 12, 16]
    |> Enum.with_index
    |> Enum.map(fn({afterq, before}) ->
      e = %Event{delta_time: before}
      e2 = Event.quantize(e, 0, 4)
      assert(e2.delta_time == afterq)
    end)

    # Test with quantize(6)
    [0, 0, 0, 6, 6, 6, 6, 6, 6, 12, 12, 12, 12, 12, 12, 18, 18, 18, 18, 18, 18, 24]
    |> Enum.with_index
    |> Enum.map(fn({afterq, before}) ->
      e = %Event{delta_time: before}
      e2 = Event.quantize(e, 0, 6)
      assert(e2.delta_time == afterq)
    end)
  end

  test "quantize 2" do
    [{0, 0},
     {1, 0},
     {70, 80},
     {100, 80},
     {398, 400},
     {405, 400},
     {440, 480},
     {441, 480}]
    |> Enum.map(fn({orig, expected}) ->
      e = %Event{delta_time: orig}
      e2 = Event.quantize(e, 0, 80)
      assert(e2.delta_time == expected)
    end)
  end

  test "quantize when prev delta is not zero" do
     # sum(prev events' delta), orig delta, expected delta
    [{ 80,   0,   0},
     { 78,   0,   2},
     {  0, 100,  80},
     {100, 100, 140},
     {200, 100, 120}]
    |> Enum.map(fn({prev_delta, orig, expected}) ->
      e = %Event{delta_time: orig}
      e2 = Event.quantize(e, prev_delta, 80)
      assert(e2.delta_time == expected)
    end)
  end
end
