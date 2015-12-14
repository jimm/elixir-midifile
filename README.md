# Midifile

[Note: This README is currently a slightly mutated copy of
https://github.com/jimm/midilib/blob/master/README.rdoc, so don't pay too
much attention to it yet.]

Midifile is a library useful for reading and writing standard type 1 MIDI
files and manipulating MIDI event data.

The GitHub project page and Web site of Midifile is
http://github.com/jimm/elixir-midifile and the Hex page is
https://hex.pm/packages/midifile.


## Installation

TODO

## Testing

  % mix test

runs all of the tests in the test directory.


## Overview

The Midifile MIDI file reader only understands MIDI file format 1, where a
sequence is made up of multiple tracks. It doesn't yet understand format 0
(a single track containing all events) or format 2 (a collection of format 0
files in one file).

### Midifile.Sequence

A sequence contains a list of tracks and global information like the
sequence's format (always 1 for Midifile) and time division.

The first track in a sequence is special; it holds meta-events like tempo
and sequence name. It is stored as a sequence's `conductor_track`. Don't put
any notes in this track.

`Midifile.Sequence` also contains some convenience methods that let you [set
and] retrieve the sequence's name, [the time signature, and to retrieve the
first tempo event's beats-per-minute value].

### Midifile.Track

A track contains an array of events.

When you modify the `events` array, make sure to call recalc_times so each
event gets its `time_from_start` recalculated. You don't have to do that
after every event you add; just remember to do so before using the track in
a way that expects the list of events to be ordered correctly.

A Track also holds a bit mask that specifies the channels used by the track.
This bit mask is set when the track is read from the MIDI file by a SeqReader
but is _not_ kept up to date by any other methods. Specifically, if you add
events to a track at any other time, the bit mask will not be updated.

### Midifile.Measure

This class contains information about a measure from the sequence. Measure
data is based on the time signature information from the sequence and is not
stored in the sequence itself.

### Midifile.Measures

The class Midifile.Sequence method get_measures returns a Midifile.Measures object.
Midifile.Measures is a subclass of Array. It is a specialized container for
Midifile.Measure objects, which can be use to map event times to measure numbers.
Please note that this object has to be remade when events are deleted/added in
the sequence.

Midifile.Measure and Midifile.Measures are brought to us by Jari Williamsson
<jari.williamsson@mailbox.swipnet.se>, who also contributed some improvements
to the Midifile.Event and Midifile.Track classes.

### Midifile.Event

Each event holds not only its delta time but also its time from the start of
the track. The track is responsible for recalculating its events' start times.
You can call Midifile.Track#recalc_times to do so.

Subclasses of Midifile.Event implement the various MIDI messages such as note on
and off, controller values, system exclusive data, and realtime bytes.

Midifile.Realtime events have delta values and start times, just like all the
other Midifile event types do. (MIDI real time status bytes don't have delta
times, but this way we can record when in a track the realtime byte was
received and should be sent. This is useful for start/continue/stop events
that control other devices, for example.) Note that when a Midifile.Realtime
event is written out to a MIDI file, the delta time is not written.

Midifile.MetaEvent events hold an array of bytes named 'data'. Many meta events
are string holders (text, lyric, marker, etc.) Though the 'data' value is
always an array of bytes, Midifile.MetaEvent helps with saving and accessing
string. The Midifile.MetaEvent#data_as_str method returns the data bytes as a
string. When assigning to a meta event's data, if you pass in a string it will
get converted to an array of bytes.


## How To Use

The following examples show you how to use Midifile to read, write, and
manipulate MIDI files and modify track events. See also the files in the
examples directory, which are described below.


### Reading a MIDI File

To read a MIDI file, create a Midifile.Sequence object and call its #read method,
passing in an IO object.

The #read method takes an optional block. If present, the block is called
once after each track has finished being read. Each time, it is passed the
track object, the total number of tracks and the number of the current track
that has just been read. This is useful for notifying the user of progress,
for example by updating a GUI progress bar.

 require 'Midifile/io/seqreader'

 # Create a new, empty sequence.
 seq = Midifile.Sequence.new()

 # Read the contents of a MIDI file into the sequence.
 File.open('my_midi_file.mid', 'rb') { | file |
     seq.read(file) { | track, num_tracks, i |
         # Print something when each track is read.
         puts "read track #{i} of #{num_tracks}"
     }
 }


### Writing a MIDI File

To write a MIDI file, call the write method, passing in an IO object.


 require 'Midifile/io/seqwriter'

 # Start with a sequence that has something worth saving.
 seq = read_or_create_seq_we_care_not_how()

 # Write the sequence to a MIDI file.
 File.open('my_output_file.mid', 'wb') { | file | seq.write(file) }


### Editing a MIDI File

Combining the last two examples, here is a script that reads a MIDI file,
transposes some events, and writes the sequence out to a different file. This
is a useful template for programatically manipulating MIDI data.


This code transposes all of the note events (note on, note off, and poly
pressure) on channel 5 down one octave.

#### Transposing One Channel

 require 'Midifile/io/seqreader'
 require 'Midifile/io/seqwriter'

 # Create a new, empty sequence.
 seq = Midifile.Sequence.new()

 # Read the contents of a MIDI file into the sequence.
 File.open('my_input_file.mid', 'rb') { | file |
     seq.read(file) { | track, num_tracks, i |
         # Print something when each track is read.
         puts "read track #{i} of #{num_tracks}"
     }
 }

 # Iterate over every event in every track.
 seq.each { | track |
     track.each { | event |
         # If the event is a note event (note on, note off, or poly
         # pressure) and it is on MIDI channel 5 (channels start at
         # 0, so we use 4), then transpose the event down one octave.
         if Midifile.NoteEvent === event && event.channel == 4
             event.note -= 12
         end
     }
 }

 # Write the sequence to a MIDI file.
 File.open('my_output_file.mid', 'wb') { | file | seq.write(file) }


### Manipulating tracks

If you modify a track's list of events directly, don't forget to call
Midifile.Track#recalc_times when you are done.

 track.events[42, 1] = array_of_events
 track.events << an_event
 track.merge(array_of_events)
 track.recalc_times

### Calculating delta times

A few methods in Midifile.Sequence make it easier to calculate the delta times
that represent note lengths. Midifile.Sequence#length_to_delta takes a note
length (a multiple of a quarter note) and returns the delta time given the
sequence's current ppqn (pulses per quarter note) setting. 1 is a quarter
note, 1.0/32.0 is a 32nd note (use floating-point numbers to avoid integer
rounding), 1.5 is a dotted quarter, etc. See the documentation for that method
for more information.

Midifile.Sequence#note_to_length takes a note name and returns a length value
(again, as a multiple of a quarter note). Legal note names are those found in
Midifile.Sequence::NOTE_TO_LENGTH, and may begin with "dotted" and/or end with
"triplet". For example, "whole", "sixteenth", "32nd", "quarter triplet",
"dotted 16th", and "dotted 8th triplet" are all legal note names.

Finally, Midifile.Sequence#note_to_delta takes a note name and returns a delta
time. It does this by calling note_to_length, then passing the result to
length_to_delta.


### Example Scripts

Here are short descriptions of each of the examples found in the examples
directory.

* examples/from_scratch.rb shows you how to create a new sequence from scratch
  and save it to a MIDI file. It creates a file called 'from_scratch.mid'.

* examples/seq2text.rb dumps a MIDI file as text. It reads in a sequence and
  uses the to_s method of each event.

* examples/reader2text.rb dumps a MIDI file as text. It subclasses
  Midifile.SeqReader instead of creating a sequence containing tracks and events.

* examples/transpose.rb transposes all note events (note on, note off, poly
  pressure) on a specified channel by a specified amount.

* There is also one MIDI file, examples/NoFences.mid. It is a little pop ditty
  I wrote. The instruments in this file use General MIDI patch numbers and
  drum note assignments. Since I don't normally use GM patches, the sounds
  used here are at best approximations of the sounds I use.


## Resources

A description of the MIDI file format can be found in a few places such as
https://www.csie.ntu.edu.tw/~r92092/ref/midi/.

The MIDI message reference at http://www.jimmenard.com/midi_ref.html
describes the format of MIDI commands.


# To Do


# Support

* Visit the forums, bug list, and mailing list pages at
  http://rubyforge.org/projects/Midifile

* Send email to Jim Menard at mailto:jim@jimmenard.com

* Ask on the ruby-talk mailing list


# Administrivia

Author:: Jim Menard (mailto:jim@jimmenard.com)
Copyright:: Copyright (c) 2015 Jim Menard
License:: Distributed under the same license as Elixir: Apache v2.0.


## Copying

Midifile is copyrighted free software by Jim Menard and is released under the
same license as Elixir: Apache v2.0.

Midifile may be freely copied in its entirety providing this notice, all
source code, all documentation, and all other files are included.

Midifile is Copyright (c) 2015 by Jim Menard.


## Recent Changes


## Warranty

This software is provided "as is" and without any express or implied
warranties, including, without limitation, the implied warranties of
merchantability and fitness for a particular purpose.
