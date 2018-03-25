// A Monome 128 Grid and Illucia DTR live sequencer, synthesizer
(
// make a new clock
~clock = TempoClock.new();
// Make a new Monome and use it
~monome = MonoM.new("/monome", 0);
~monome.useDevice(0);

// make the top right knob on the illucia control the tempo. This assumes the Illucia is connected via the Illucia Connect driver app
// TODO: Make an Illucia class based on the MonoM class that does dynamic discovery stuffs
OSCFunc.newMatching( { arg message, time, addr, recvPort;
	if (message[1] > 0) {
	~clock.tempo = message[1];
	}
}, "/dtr/Continuous/1", recvPort: 12001
);

// turn off all the LEDs on the grid before we start
~monome.ledall(0);
// Set the default server to the local server
Server.default = Server.local;

// Make some SynthDefs to load up later
SynthDef(\singrain, { |freq = 440, amp = 0.2, sustain = 1|
    var sig;
    sig = SinOsc.ar(freq, 0, amp) * EnvGen.kr(Env.perc(0.01, sustain), doneAction: 2);
    Out.ar(0, sig ! 2);    // sig ! 2 is the same as [sig, sig]
}).add;

// this might need an envelope or something because it takes up a huge amount of CPU
SynthDef(\klank, { | freq = 440, amp = 0.2, sustain = 1 |
	var sig;
	sig = Klank.ar(`[[freq, freq*1.3, freq*1.5, freq*1.7], nil, [sustain, sustain, sustain, sustain]], Impulse.ar(0, 0, amp));
	Out.ar(0, sig ! 2);
}).add;

// wait for the server to boot before running the sequencer functions
s.waitForBoot({
	~step = Array.fill(96, {0}); // Make a 96 step array and fill each step with zeros
	~play_position = 0; // the play position is the current spot of the playhead
	~next_position = 0; // the next position is one after the play position?
	~cutting = 0;       // ???
	~keys_held = 0;     // how many keys are held down right now?
	~key_last = 0;      // ???
	~loop_start = 0;    // which step is the start of the loop?
	~loop_end = 15;     // which step is the end of the loop?

	//The OSC Function matching a key event on the grid
	OSCFunc.newMatching({ arg message, time, addr, recvPort;
		message.postln;

		// toggles if the button is pressed and the row is between 1 and 6
		if((message[3] == 1) && (message[2] < 6), {
			var pos = message[1] + (message[2] * 16); // the position is the column added to the row times 16
			// flip the bit for any LED state when a button is pressed. Clever.
			if(~step[pos] == 1,
				{~step[pos] = 0},
				{~step[pos] = 1}
			);
		});
		// if the row is seven and the button is pressed, increment ~keys_held by one, otherwise decrement to one
		if(message[2] == 7,
			if(message[3] == 1,
				{~keys_held = ~keys_held + 1;},
				{~keys_held = ~keys_held - 1;});
		);
		// if a button is pressed on the seventh row
		if((message[3] == 1) && (message[2] == 7), {
			// if a single key is held set the next position to the column, enable cutting set the last key to the column
			if(~keys_held == 1, {
				~next_position = message[1];
				~cutting = 1;
				~key_last = message[1];
			},
			// otherwise set the loop start to the last key and set the loop end to the column of the current key
			// This doesn't check bounds but it looks like that is intentional.
			{
				~loop_start = ~key_last;
				~loop_start.postln;
				~loop_end = message[1];
				~loop_end.postln;
			});
		});
	}, "/monome/grid/key");

	// store a function to manage all LED display.
	d = {
		// use a highlight brightness to make a varibright look cooler
		var highlight;
		// call this function 16 times with the current iteration as an arg in x
		for(0,15, {arg x;
			// if this iteration is the play position set a highlight bit
			if(x==~play_position,
					{highlight = 1},
					{highlight = 0});
			// call this function six times with the current iteration as an arg in y
			for(0,5, {arg y;
				// set the LED at (x,y) to 11 if the current step is on and add 4 if we are on the play position
				// (does nothing on monobright)
				~m.levset(x,y,(~step[y*16+x] * 11) + (highlight * 4));
			});

			// set trigger row background to a soft light (does nothing on monobright)
			~m.levset(x,6,4);

			// clear play position row
			~m.levset(x,7,0);
		});

		// play position
		~m.levset(~play_position,7,15);

		// show triggers
		// call this function five times if the current step is the play position light up the sixth row
		// keys (6,6) to (15,6) are unused
		for(0,5, {arg t;
			if(~step[(t*16) + ~play_position] == 1,
				{~m.levset(t,6,15);}
			)
		});
	};
	t = Routine({
		// set an interval in seconds
		var interval = 0.125;
		loop {
			// update position
			// if we are cutting the play position is the next next position
			if(~cutting == 1,
				{~play_position = ~next_position; ~cutting = 0;},
				{
					// if we are at the end of the loop, loop back to zero,
					if(~play_position == 15,
						{~play_position = 0;},
						{
							// if the play position is the loop end, set the play position to the loop start
							// otherwise set the play position to the next step
							if(~play_position == ~loop_end,
								{~play_position = ~loop_start;},
								{~play_position = ~play_position + 1;});
						}
					);
				};
			);

			// TRIGGER SOMETHING
			for(0,5, {arg t;
				// if the step we are on is on, run this synth once
				if(~step[(t*16) + ~play_position] == 1,
					{Synth(\singrain, [freq: (5-t)*100+300,
						amp: rrand(0.1, 0.5), sustain: interval * 2]);}
				)
			});
			// evaluate the function named d
			d.value;
			// yield to a number, which will repeat this Routine after waiting this many seconds
			interval.yield;
		}
	});
	~clock.sched(0,t); // schedule the Routine t to play immediately using the rate of the TempoClock
})
)
