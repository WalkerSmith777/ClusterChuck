//ClusterChuck
//Cluster Contraction Analysis / Resynthesis Implementation in Chuck

/*
The idea for this algorithm came from my sonification research, where I 
convert the visible emission spectral of chemical elements into sounds. 
An element's emission spectrum is a series of electromagnetic waves with
distinct frequencies (colors) and amplitudes (brighteness). To sonify these,
I simple map each frequency of light to a frequency of sound by dividing all
frequencies by a factor ~10^12 to place them into the audible range of 20Hz-20kHz.
The brightness of each line determines the amplitude of that sine wave.

*/

//with adc input
adc => FFT fft => blackhole;
// synthesize
0.5 => global float gain;
gain => float gain_val;
IFFT ifft => Gain g(gain_val) => dac;


440 => global float freq;
0.1 => global float target_min_freq_slider;
target_min_freq_slider * 10000 => float target_min_freq;
target_min_freq * 2 => float target_max_freq;
gain => gain_val;

fun void update_freq(){
    while(true){
        //freq * 1000. => sin.freq;
        target_min_freq_slider * 10000 => target_min_freq;
        target_min_freq * 2 => target_max_freq;
        gain => g.gain;
        1000::samp => now;
    }
}

spork ~update_freq();

/*
target_min_freq_slider * 10000 => float target_min_freq;

*/
second / samp => float srate;

// set parameters
//2048 => fft.size;
4096 => fft.size;
//256 => fft.size;
//32768 => fft.size;
fft.size() => int win_size;
win_size / 4 => int hop_size;
// use this to hold contents
complex s[fft.size()/2];

srate / fft.size() => float bin_width;
// window
Windowing.hann(win_size) => fft.window;
Windowing.hann(win_size) => ifft.window;

//0. => global float threshold;

//create polar arrays of fft 
fun float max_amp() {
    
    polar sorted_polar_vals[s.size()];
    s[0] $ polar => polar polar_val;
    polar_val.mag => float max_amp;
    
    for(0=>int i; i<s.size(); i++){
        s[i] $ polar => polar polar_value;
        if(polar_value.mag > max_amp){
            polar_value.mag => max_amp;
        }
      
    }
    return max_amp;
}


0. => global float h;

// control loop
fun void cluster_chuck(int start_bin, int end_bin, float max_amp, polar polar_values[]) {
    
    // take fft
    // fft.upchuck();
    
    // get contents
    // fft.spectrum( s );
    

    //process spectral contents
    for(start_bin=>int i; i<end_bin; i++){
        i * srate/fft.size() => float freq;

        0 => int octave_displacement;

        polar_values[i].mag => float amp;

        if(amp < max_amp * h){
            Math.floor(Math.log(amp / max_amp) / Math.log(h) ) $ int => octave_displacement;

            if(freq < target_min_freq){
                Math.abs(octave_displacement) => octave_displacement;  // Positive octave displacement, shift up
                Math.floor(Math.log2(target_max_freq / freq)) $ int => int od_max; // Maximum oct displ. to avoid exceeding the target range
                if(octave_displacement > od_max){
                    od_max => octave_displacement;
                }
            }
            else if(freq > target_max_freq){
                -Math.abs(octave_displacement) => octave_displacement; // Negative oct displacement, shift down
                Math.floor(Math.log2(target_min_freq / freq)) $ int => int od_min;
                if(octave_displacement < od_min){
                    od_min => octave_displacement;
                }
            }
            else if(freq < target_max_freq && freq > target_min_freq){
                0 => octave_displacement;
            }
            
            //<<<i, amp, h, octave_displacement>>>;
            

            freq * Math.pow(2, octave_displacement) => float new_freq;

            new_freq / bin_width => float bin_value;

            Math.floor(bin_value) $ int => int lower_bin;
            Math.ceil(bin_value) $ int => int upper_bin;

            bin_value - lower_bin => float binterpolation;

            amp * binterpolation => float lower_bin_amp;
            amp * (1-binterpolation) => float upper_bin_amp;

            polar_values[lower_bin].phase => float theta_lower;
            polar_values[upper_bin].phase => float theta_upper;

            %(lower_bin_amp, theta_lower) => polar p_lower_bin;
            %(upper_bin_amp, theta_upper) => polar p_upper_bin;

            p_lower_bin +=> polar_values[lower_bin];
            p_upper_bin +=> polar_values[upper_bin];
            p_lower_bin $ complex => s[lower_bin];
            p_upper_bin $ complex => s[upper_bin];
        
            //Remove the frequency from the bin that it initially was in
            %(0, 0*pi) => polar new_bin_value;
            new_bin_value $ complex => s[i];
            
        }       

        /*
        //
        s[i] $ polar @=> polar_values[i];
        
        polar_values[i] => polar polar_val;
        
        if(polar_values[i].mag >= threshold/100.) {
           //<<< i, i * srate/fft.size(), polar_values[i].mag >>>;
           //<<< 1, 1 * srate/fft.size()>>>;
        }
        
        if(polar_values[i].mag >= max_amp) {
           <<< i, i * srate/fft.size(), polar_values[i].mag, max_amp>>>;
        }
        
        if(polar_val.mag <= threshold/100.) {
            0 => complex val;
            val => s[i];

            // s[i] => s[i];
            // <<<i>>>;
            // <<<"h">>>;
            
        }
        */
        

        // else{
        //     0 => complex val;
        //     val => s[i];
        //     <<<"not h">>>;
        //     //<<<val>>>;
        // }
        // advance time
        
    }
    
    // hop_size::samp => now;
    // ifft.transform(s);
}

while(true) {
    fft.upchuck();
    fft.spectrum( s );

    0 => int start_bin;
    32 => int num_fft_processes;
    s.size()/num_fft_processes => int bin_length => int end_bin;

    polar polar_values[s.size()];

    for(0=>int i; i<s.size(); i++){
        s[i] $ polar => polar_values[i];
    }

    max_amp() => float maximum_amp; 
    //<<< maximum_amp >>>;
    for(0=>int i; i<num_fft_processes; i++){
       
        cluster_chuck(start_bin, end_bin, maximum_amp, polar_values);   
        
        start_bin + bin_length => start_bin;
       
        end_bin + bin_length => end_bin;
    }

    // // advance time
    hop_size::samp => now;
    ifft.transform(s);
    
}

//spork ~spectral_gate(start_bin, end_bin);
eon => now;
