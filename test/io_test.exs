Code.require_file "test_helper.exs", __DIR__

defmodule IoTest do
  use ExUnit.Case

  @seq_test_file :filename.join(__DIR__, "test.mid")
  @output_file "/tmp/testout.mid"

  def compare_tracks(t0, t1) do
    assert(t0.name == t1.name)
    assert(length(t0.events) == length(t1.events))
    assert(t0.events == t1.events)
  end

  def compare_sequences(s0, s1) do
    assert(Sequence.name(s0) == Sequence.name(s1))
    assert(length(s0.tracks) == length(s1.tracks))
    Enum.zip(s0.tracks, s1.tracks)
    |> Enum.map(fn({t0, t1}) -> compare_tracks(t0, t1) end)
  end

  test "read and write" do
    seq0 = Midifile.read(@seq_test_file)
    Midifile.write(seq0, @output_file)
    seq1 = Midifile.read(@output_file)
    compare_sequences(seq0, seq1)
    File.rm(@output_file)
  end

  test "read strings" do
    seq0 = Midifile.read(@seq_test_file)
    assert(Sequence.name(seq0) == "Sequence Name")
    t0 = hd(seq0.tracks)
    assert("Acoustic Grand Piano" == Track.instrument(t0))
  end
end
