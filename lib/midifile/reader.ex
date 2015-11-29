defmodule Midifile.Reader do

  use Bitwise
  alias Midifile.Varlen

  @moduledoc """
  MIDI file reader.
  """
  
  @debug false

  # Channel messages
  @status_nibble_off 0x8
  @status_nibble_on 0x9
  @status_nibble_poly_press 0xA
  @status_nibble_controller 0xB
  @status_nibble_program_change 0xC
  @status_nibble_channel_pressure 0xD
  @status_nibble_pitch_bend 0xE

  # System common messages
  @status_sysex 0xF0
  @status_song_pointer 0xF2
  @status_song_select 0xF3
  @status_tune_request 0xF6
  @status_eox 0xF7

  # System realtime messages
  # MIDI clock (24 per quarter note) klrjb
  @status_clock 0xF8
  # Sequence start
  @status_start 0xFA
  # Sequence continue
  @status_continue 0xFB
  # Sequence stop
  @status_stop 0xFC
  # Active sensing (sent every 300 ms when nothing else being sent)
  @status_active_sense 0xFE
  # System reset
  @status_system_reset 0xFF

  # Meta events
  @status_meta_event 0xFF
  @meta_seq_num 0x00
  @meta_text 0x01
  @meta_copyright 0x02
  @meta_seq_name 0x03
  @meta_instrument 0x04
  @meta_lyric 0x05
  @meta_marker 0x06
  @meta_cue 0x07
  @meta_midi_chan_prefix 0x20
  @meta_track_end 0x2f
  @meta_set_tempo 0x51
  @meta_smpte 0x54
  @meta_time_sig 0x58
  @meta_key_sig 0x59
  @meta_sequencer_specific 0x7F

  @doc """
  Returns a Sequence  record.
  """

  def read(path) do
    {:ok, f} = File.open(path, [:read, :binary])
    pos = look_for_chunk(f, 0, "MThd", :file.pread(f, 0, 4))
    [header, num_tracks] = parse_header(:file.pread(f, pos, 10))
    tracks = read_tracks(f, num_tracks, pos + 10, [])
    File.close(f)
    [conductor_track | remaining_tracks] = tracks
    %Sequence{header: header, conductor_track: conductor_track, tracks: remaining_tracks}
  end

  defp debug(msg) do
    if @debug, do: IO.puts(msg), else: nil
  end

  # Only reason this is a macro is for speed.
  defmacro chan_status(status_nibble, chan) do
    quote do: (unquote(status_nibble) <<< 4) + unquote(chan)
  end

  # Look for Cookie in file and return file position after Cookie.
  defp look_for_chunk(_f, pos, cookie, {:ok, cookie}) do
    debug("look_for_chunk")
    pos + byte_size(cookie)
  end

  defp look_for_chunk(f, pos, cookie, {:ok, _}) do
    debug("look_for_chunk")
    # This isn't efficient, because we only advance one character at a time.
    # We should really look for the first char in Cookie and, if found,
    # advance that far.
    look_for_chunk(f, pos + 1, cookie, :file.pread(f, pos + 1, byte_size(cookie)))
  end

  defp parse_header({:ok, <<_bytes_to_read::size(32), format::size(16), num_tracks::size(16), division::size(16)>>}) do
    debug("parse_header")
    [{:header, format, division}, num_tracks]
  end

  defp read_tracks(_f, 0, _pos, tracks) do
    debug("read_tracks")
    :lists.reverse(tracks)
  end

  # TODO: make this distributed. Would need to scan each track to get start
  # position of next track.

  defp read_tracks(f, num_tracks, pos, tracks) do
    debug("read_tracks")
    [track, next_track_pos] = read_track(f, pos)
    read_tracks(f, num_tracks - 1, next_track_pos, [track|tracks])
  end

  defp read_track(f, pos) do
    debug("read_track")
    track_start = look_for_chunk(f, pos, "MTrk", :file.pread(f, pos, 4))
    bytes_to_read = parse_track_header(:file.pread(f, track_start, 4))
    Process.put(:status, 0)
    Process.put(:chan, -1)
    [%Track{events: event_list(f, track_start + 4, bytes_to_read, [])}, track_start + 4 + bytes_to_read]
  end

  defp parse_track_header({:ok, <<bytes_to_read::size(32)>>}) do
    debug("parse_track_header")
    bytes_to_read
  end

  defp event_list(_f, _pos, 0, events) do
    debug("event_list")
    :lists.reverse(events)
  end

  defp event_list(f, pos, bytes_to_read, events) do
    debug("event_list")
    {:ok, bin} = :file.pread(f, pos, 4)
    [delta_time, var_len_bytes_used] = Varlen.read(bin)
    {:ok, three_bytes} = :file.pread(f, pos + var_len_bytes_used, 3)
    [event, event_bytes_read] = read_event(f, pos + var_len_bytes_used, delta_time, three_bytes)
    bytes_read = var_len_bytes_used + event_bytes_read
    event_list(f, pos + bytes_read, bytes_to_read - bytes_read, [event|events])
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_off::size(4), chan::size(4), note::size(8), vel::size(8)>>) do
    debug("read_event <<@status_nibble_off::size(4), chan::size(4), note::size(8), vel::size(8)>>")
    Process.put(:status, @status_nibble_off)
    Process.put(:chan, chan)
    [%Event{symbol: :off, delta_time: delta_time, bytes: [chan_status(@status_nibble_off, chan), note, vel]}, 3]
  end

  # note on, velocity 0 is a note off
  defp read_event(_f, _pos, delta_time, <<@status_nibble_on::size(4), chan::size(4), note::size(8), 0::size(8)>>) do
    debug("read_event <<@status_nibble_on::size(4), chan::size(4), note::size(8), 0::size(8)>>")
    Process.put(:status, @status_nibble_on)
    Process.put(:chan, chan)
    [%Event{symbol: :off, delta_time: delta_time, bytes: [chan_status(@status_nibble_off, chan), note, 64]}, 3]
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_on::size(4), chan::size(4), note::size(8), vel::size(8)>>) do
    debug("read_event <<@status_nibble_on::size(4), chan::size(4), note::size(8), vel::size(8)>>")
    Process.put(:status, @status_nibble_on)
    Process.put(:chan, chan)
    [%Event{symbol: :on, delta_time: delta_time, bytes: [chan_status(@status_nibble_on, chan), note, vel]}, 3]
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_poly_press::size(4), chan::size(4), note::size(8), amount::size(8)>>) do
    debug("read_event <<@status_nibble_poly_press::size(4), chan::size(4), note::size(8), amount::size(8)>>")
    Process.put(:status, @status_nibble_poly_press)
    Process.put(:chan, chan)
    [%Event{symbol: :poly_press, delta_time: delta_time, bytes: [chan_status(@status_nibble_poly_press, chan), note, amount]}, 3]
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_controller::size(4), chan::size(4), controller::size(8), value::size(8)>>) do
    debug("read_event <<@status_nibble_controller::size(4), chan::size(4), controller::size(8), value::size(8)>>")
    Process.put(:status, @status_nibble_controller)
    Process.put(:chan, chan)
    [%Event{symbol: :controller, delta_time: delta_time, bytes: [chan_status(@status_nibble_controller, chan), controller, value]}, 3]
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_program_change::size(4), chan::size(4), program::size(8), _::size(8)>>) do
    debug("read_event <<@status_nibble_program_change::size(4), chan::size(4), program::size(8), _::size(8)>>")
    Process.put(:status, @status_nibble_program_change)
    Process.put(:chan, chan)
    [%Event{symbol: :program, delta_time: delta_time, bytes: [chan_status(@status_nibble_program_change, chan), program]}, 2]
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_channel_pressure::size(4), chan::size(4), amount::size(8), _::size(8)>>) do
    debug("read_event <<@status_nibble_channel_pressure::size(4), chan::size(4), amount::size(8), _::size(8)>>")
    Process.put(:status, @status_nibble_channel_pressure)
    Process.put(:chan, chan)
    [%Event{symbol: :chan_press, delta_time: delta_time, bytes: [chan_status(@status_nibble_channel_pressure, chan), amount]}, 2]
  end

  defp read_event(_f, _pos, delta_time, <<@status_nibble_pitch_bend::size(4), chan::size(4), 0::size(1), lsb::size(7), 0::size(1), msb::size(7)>>) do
    debug("read_event <<@status_nibble_pitch_bend::size(4), chan::size(4), 0::size(1), lsb::size(7), 0::size(1), msb::size(7)>>")
    Process.put(:status, @status_nibble_pitch_bend)
    Process.put(:chan, chan)
    [%Event{symbol: :pitch_bend, delta_time: delta_time, bytes: [chan_status(@status_nibble_pitch_bend, chan), <<0::size(2), msb::size(7), lsb::size(7)>>]}, 3]
  end

  defp read_event(_f, _pos, delta_time, <<@status_meta_event::size(8), @meta_track_end::size(8), 0::size(8)>>) do
    debug("read_event <<@status_meta_event::size(8), @meta_track_end::size(8), 0::size(8)>>")
    Process.put(:status, @status_meta_event)
    Process.put(:chan, 0)
    [%Event{symbol: :track_end, delta_time: delta_time, bytes: []}, 3]
  end

  defp read_event(f, pos, delta_time, <<@status_meta_event::size(8), type::size(8), _::size(8)>>) do
    debug("read_event <<@status_meta_event::size(8), type::size(8), _::size(8)>>")
    Process.put(:status, @status_meta_event)
    Process.put(:chan, 0)
    {:ok, bin} = :file.pread(f, pos + 2, 4)
    [length, length_bytes_used] = Varlen.read(bin)
    length_before_data = length_bytes_used + 2
    {:ok, data} = :file.pread(f, pos + length_before_data, length)
    total_length = length_before_data + length
    case type do
      @meta_seq_num ->
        debug("@meta_seq_num")
        [%Event{symbol: :seq_num, delta_time: delta_time, bytes: [data]}, total_length]
      @meta_text ->
        debug("@meta_text")
        [%Event{symbol: :text, delta_time: delta_time, bytes: data}, total_length]
      @meta_copyright ->
        debug("@meta_copyright")
        [%Event{symbol: :copyright, delta_time: delta_time, bytes: data}, total_length]
      @meta_seq_name ->
        debug("@meta_seq_name")
        [%Event{symbol: :seq_name, delta_time: delta_time, bytes: data}, total_length]
      @meta_instrument ->
        debug("@meta_instrument")
        [%Event{symbol: :instrument, delta_time: delta_time, bytes: data}, total_length]
      @meta_lyric ->
        debug("@meta_lyric")
        [%Event{symbol: :lyric, delta_time: delta_time, bytes: data}, total_length]
      @meta_marker ->
        debug("@meta_marker")
        [%Event{symbol: :marker, delta_time: delta_time, bytes: data}, total_length]
      @meta_cue ->
        debug("@meta_cue")
        [%Event{symbol: :cue, delta_time: delta_time, bytes: data}, total_length]
      @meta_midi_chan_prefix ->
        debug("@meta_midi_chan_prefix")
        [%Event{symbol: :midi_chan_prefix, delta_time: delta_time, bytes: [data]}, total_length]
      @meta_set_tempo ->
        debug("@meta_set_tempo")
        # data is microseconds per quarter note, in three bytes
        <<b0::size(8), b1::size(8), b2::size(8)>> = data
        [%Event{symbol: :tempo, delta_time: delta_time, bytes: [(b0 <<< 16) + (b1 <<< 8) + b2]}, total_length]
      @meta_smpte ->
        debug("@meta_smpte")
        [%Event{symbol: :smpte, delta_time: delta_time, bytes: [data]}, total_length]
      @meta_time_sig ->
        debug("@meta_time_sig")
        [%Event{symbol: :time_signature, delta_time: delta_time, bytes: [data]}, total_length]
      @meta_key_sig ->
        debug("@meta_key_sig")
        [%Event{symbol: :key_signature, delta_time: delta_time, bytes: [data]}, total_length]
      @meta_sequencer_specific ->
        debug("@meta_sequencer_specific")
        [%Event{symbol: :seq_name, delta_time: delta_time, bytes: [data]}, total_length]
      unknown ->
        debug("unknown meta")
        IO.puts "unknown == #{unknown}" # DEBUG
        [%Event{symbol: :unknown_meta, delta_time: delta_time, bytes: [type, data]}, total_length]
    end
  end

  defp read_event(f, pos, delta_time, <<@status_sysex::size(8), _::size(16)>>) do
    debug("read_event <<@status_sysex::size(8), _::size(16)>>")
    Process.put(:status, @status_sysex)
    Process.put(:chan, 0)
    {:ok, bin} = :file.pread(f, pos + 1, 4)
    [length, length_bytes_used] = Varlen.read(bin)
    {:ok, data} = :file.pread(f, pos + length_bytes_used, length)
    [{:sysex, delta_time, [data]}, length_bytes_used + length]
  end

  # Handle running status bytes
  defp read_event(f, pos, delta_time, <<b0::size(8), b1::size(8), _::size(8)>>) when b0 < 128 do
    debug("read_event <<b0::size(8), b1::size(8), _::size(8)>>")
    status = Process.get(:status)
    chan = Process.get(:chan)
    [event, num_bytes] = read_event(f, pos, delta_time, <<status::size(4), chan::size(4), b0::size(8), b1::size(8)>>)
    [event, num_bytes - 1]
  end

  defp read_event(_f, _pos, delta_time, <<unknown::size(8), _::size(16)>>) do
    debug("read_event <<unknown::size(8), _::size(16)>>, unknown = #{unknown}")
    Process.put(:status, 0)
    Process.put(:chan, 0)
    # exit("unknown status byte " ++ unknown).
    [{:unknown_status, delta_time, [unknown]}, 3]
  end

end
