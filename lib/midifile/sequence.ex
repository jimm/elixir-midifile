defmodule Midifile.Sequence do

  @default_bpm 120

  use Bitwise

  defstruct format: 1, division: 480,
    conductor_track: nil,
    tracks: []

  def name(%Midifile.Sequence{conductor_track: nil}), do: ""
  def name(%Midifile.Sequence{conductor_track: %Midifile.Track{events: []}}),  do: ""
  def name(%Midifile.Sequence{conductor_track: %Midifile.Track{events: list}})  do
    Enum.find(list, %Midifile.Event{}, &(&1.symbol == :seq_name)).bytes
  end

  def bpm(%Midifile.Sequence{conductor_track: nil}), do: @default_bpm
  def bpm(%Midifile.Sequence{conductor_track: %Midifile.Track{events: []}}),  do: ""
  def bpm(%Midifile.Sequence{conductor_track: %Midifile.Track{events: list}})  do
    tempo_event = Enum.find(list, %Midifile.Event{}, &(&1.symbol == :tempo))
    if tempo_event do
      microsecs_per_beat = hd(tempo_event.bytes)
      trunc(60_000_000 / microsecs_per_beat)
    else
      @default_bpm
    end
  end

  def ppqn(seq) do
    <<0::size(1), ppqn::size(15)>> = <<seq.division::size(16)>>
    ppqn
  end
  # TODO: handle SMPTE (first bit 1, -frame/sec (7 bits), ticks/frame (8 bits))
end
