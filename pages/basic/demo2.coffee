code = """
// set the global gain
.1 => dac.gain;

SinOsc oscarray[5];
for(0 => int i; i<5; i++) {
  oscarray[i] => dac;
  Math.pow(2, i) * 110.0 => oscarray[i].freq;
}

for(0 => int j; j<5; j++) {
  oscarray[j] =< dac;
  1::second => now;
}
"""
