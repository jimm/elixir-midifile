defmodule Midifile do

  def read(path) do
    Midifile.Reader.read(path)
  end

  def write(sequence, path) do
    Midifile.Writer.write(sequence, path)
  end

end
