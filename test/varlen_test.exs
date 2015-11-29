defmodule VarlenTest do
  use ExUnit.Case

  alias Midifile.Varlen

  @data [
         {0x00000000, 0x00, 1},
         {0x00000040, 0x40, 1},
         {0x0000007F, 0x7F, 1},
         {0x00000080, 0x8100, 2},
         {0x00002000, 0xC000, 2},
         {0x00003FFF, 0xFF7F, 2},
         {0x00004000, 0x818000, 3},
         {0x00100000, 0xC08000, 3},
         {0x001FFFFF, 0xFFFF7F, 3},
         {0x00200000, 0x81808000, 4},
         {0x08000000, 0xC0808000, 4},
         {0x0FFFFFFF, 0xFFFFFF7F, 4}
    ]

  test "num to var len" do
    @data
    |> Enum.map(fn({num, answer, answer_bytes}) ->
      answer_bits = answer_bytes * 8
      assert(<<answer :: size(answer_bits)>> == Varlen.write(num))
    end)
  end

  test "var len to num" do
    @data
    |> Enum.map(fn({answer, num, num_bytes}) ->
      num_bits = num_bytes * 8
      remainder_bits = 32 - num_bits
      retval = Varlen.read(<<num :: size(num_bits), 0 :: size(remainder_bits)>>)
      assert(retval == [answer, num_bytes])
    end)
  end
end
