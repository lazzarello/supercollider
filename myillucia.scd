(
~t = TempoClock.new();

OSCFunc.newMatching( { arg message, time, addr, recvPort;
	if (message[1] > 0) {
	~t.tempo = message[1];
	}
}, "/dtr/Continuous/2", recvPort: 12001
);

// Henon map / attractor (returns points in -1.5<x<1.5, -0.4<y<0.4), which are then used for pan (x values) and degrees from a dorian scale (y values) (code adapted from Staffan Liljegren)
p = Prout({
	var x0, y0, x, y;
	x0 = 0; y0 = 0;

	loop({
		x = y0 + 1 - (1.4 * x0 * x0);
		y = 0.3 * x0;
		x0=x; y0=y;
		[x, (y*14).asInteger].yield;
	});
});

// \degree is the degree of the scale provided in \scale-
// this is where the dorian tuning comes from

~scale = [
	//Ionian Mode
   //(W-W-H-W-W-W--H)
	[0,2,4,5,7,9,11],
	//Dorian Mode
   //(W-H-W-W-W-H--W)
	[0,2,3,5,7,9,10],
	//Phrygian Mode
   //(H-W-W-W-H-W--W)
	[0,1,3,5,7,8,10],
	//Lydian Mode
   //(W-W-W-H-W-W--H)
	[0,2,4,6,7,9,11],
	//Mixolydian Mode
   //(W-W-H-W-W-H--W)
	[0,2,4,5,7,9,10],
	//Aeolian Mode
   //(W-H-W-W-H-W--W)
	[0,2,3,5,7,8,10],
	//Locrian Mode
   //(H-W-W-H-W-W--W)
	[0,1,3,5,6,8,10]
];

b = Pbind(\scale, ~scale.choose, \dur,0.125,[\pan, \degree], p);

// the order of arguments in Pbindf has been switched since SC2- this may change back again- be careful!

Ptpar([ 0.0, Pbindf(b, \octave, 4,\stretch, 3.0), 4.0, b]).play(~t);
)

/*
Pbindf is a filter Pbind - this means it operates on the Pattern b, adjusting the current properties of the environment - in this case \octave and \stretch

Note how this allows a slow version of b in the bass and a faster version higher up coming in after 4 seconds
*/