defmodule Midifile.Varlen do

  use Bitwise

  @moduledoc """
  Reads and writes varlen values.
  """

  def read(<<0::size(1), b0::size(7), _::size(24)>>) do
    [b0, 1]
  end

  def read(<<1::size(1), b0::size(7), 0::size(1), b1::size(7), _::size(16)>>) do
    [(b0 <<< 7) + b1, 2]
  end

  def read(<<1::size(1), b0::size(7), 1::size(1), b1::size(7), 0::size(1), b2::size(7), _::size(8)>>) do
    [(b0 <<< 14) + (b1 <<< 7) + b2, 3]
  end

  def read(<<1::size(1), b0::size(7), 1::size(1), b1::size(7), 1::size(1), b2::size(7), 0::size(1), b3::size(7)>>) do
    [(b0 <<< 21) + (b1 <<< 14) + (b2 <<< 7) + b3, 4]
  end

  def read(<<1::size(1), b0::size(7), 1::size(1), b1::size(7), 1::size(1), b2::size(7), 1::size(1), b3::size(7)>>) do
    # IO.puts("WARNING: bad var len format; all 4 bytes have high bit set")
    [(b0 <<< 21) + (b1 <<< 14) + (b2 <<< 7) + b3, 4]
  end

  def write(i) when i < (1 <<< 7) do
    <<0::size(1), i::size(7)>>
  end

  def write(i) when i < (1 <<< 14) do
    <<1::size(1), (i >>> 7)::size(7), 0::size(1), i::size(7)>>
  end

  def write(i) when i < (1 <<< 21) do
    <<1::size(1), (i >>> 14)::size(7), 1::size(1), (i >>> 7)::size(7), 0::size(1), i::size(7)>>
  end

  def write(i) when i < (1 <<< 28) do
    <<1::size(1), (i >>> 21)::size(7), 1::size(1), (i >>> 14)::size(7), 1::size(1), (i >>> 7)::size(7), 0::size(1), i::size(7)>>
  end

  def write(i) do
    exit("Value " ++ i ++ " is too big for a variable length number")
  end

end
