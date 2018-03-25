(
~m = MonoM.new("/monome", 0);
~m.useDevice(0);
)
SerialOSCGrid.testLeds;

OSCFunc.newMatching({ arg message, time, addr, recvPort;
	message.postln;
}, "/monome/grid/key");

~m.levset(0,1,15);
~m.ledall(0);
~m.ledall(1);

// arbitrary toggles
(
~step = Array.fill(128, {0});

OSCFunc.newMatching({ arg message, time, addr, recvPort;
	if(message[3] == 1, {
	var pos = message[1] + (message[2] * 16);
	if(~step[pos] == 1,
		{~step[pos] = 0},
		{~step[pos] = 1}
	);
	d.value
	});
}, "/monome/grid/key");


d = {
	for(0,7, {arg y;
		for(0, 15, {arg x;
			~m.levset(x,y,~step[y*16+x] * 15);
		})
	})
};
)

// step sequencer

(
~m = MonoM.new("/monome", 0);
~m.useDevice(0);
~clk = TempoClock.new;
~m.ledall(0);
Server.default = Server.local;

SynthDef(\singrain, { |freq = 440, amp = 0.2, sustain = 1|
    var sig;
    sig = SinOsc.ar(freq, 0, amp) * EnvGen.kr(Env.perc(0.01, sustain), doneAction: 2);
    Out.ar(0, sig ! 2);    // sig ! 2 is the same as [sig, sig]
}).add;

SynthDef(\klank, { | freq = 440, amp = 0.2, sustain = 1 |
	var sig;
	sig = Klank.ar(`[[freq, freq*1.3, freq*1.5, freq*1.7], nil, [sustain, sustain, sustain, sustain]], Impulse.ar(0, 0, amp));
	Out.ar(0, sig);
}).add;

s.waitForBoot({

~step = Array.fill(96, {0});
~play_position = 0;
~next_position = 0;
~cutting = 0;
~keys_held = 0;
~key_last = 0;
~loop_start = 0;
~loop_end = 15;

OSCFunc.newMatching(
		{ arg message, time, addr, recvPort;

			// toggles
			if((message[3] == 1) && (message[2] < 6), {
				var pos = message[1] + (message[2] * 16);
				if(~step[pos] == 1,
					{~step[pos] = 0},
					{~step[pos] = 1}
				);
			});

			// count bottom row keys
			if(message[2] == 7,
				if(message[3] == 1,
					{~keys_held = ~keys_held + 1;},
					{~keys_held = ~keys_held - 1;});
			);

			// loop and cut
			if((message[3] == 1) && (message[2] == 7), {
				if(~keys_held == 1, {
					~next_position = message[1];
					~cutting = 1;
					~key_last = message[1];
					},
					{
						~loop_start = ~key_last;
						~loop_end = message[1];
						~loop_end.postln;
				});
			});
		}, "/monome/grid/key");


d = {
		var highlight;
		for(0,15, {arg x;
			if(x==~play_position,
					{highlight = 1},
					{highlight = 0});

			for(0,5, {arg y;
				~m.levset(x,y,(~step[y*16+x] * 11) + (highlight * 4));
			});

			// set trigger row background
			~m.levset(x,6,4);

			// clear play position row
			~m.levset(x,7,0);
		});

		// play position
		~m.levset(~play_position,7,15);

		// show triggers
		for(0,5, {arg t;
			if(~step[(t*16) + ~play_position] == 1,
				{~m.levset(t,6,15);}
			)
		});
	};

t = Routine({
		var interval = 0.125;
	loop {
		// update position
		if(~cutting == 1,
				{~play_position = ~next_position; ~cutting = 0;},
				{
					if(~play_position == 15,
						{~play_position = 0;},
						{
							if(~play_position == ~loop_end,
								{~play_position = ~loop_start;},
								{~play_position = ~play_position + 1;});
						}
					);
				};
			);

		// TRIGGER SOMETHING
		for(0,5, {arg t;
			if(~step[(t*16) + ~play_position] == 1,
					{Synth(\singrain, [freq: (5-t)*100+300,
						amp: rrand(0.1, 0.5), sustain: interval * 2]);}
			)
		});

		d.value;

		interval.yield;
	}

});

	~clk.sched(0, t);
	~clk.tempo = 1;
// To change the tempo, use an OSCFunc that sets the TempoClock.tempo = n value on each new event
});
)