module telephone #(low = PUT A VALUE HERE, high = PUT A VALUE HERE)(
    input logic clk,
    input logic n_rst,
    input logic [17:0] y_in, 
    input logic sample_en,
    input logic [$clog2(N)-1:0] delay,
    input logic [17:0] DELAY_MS,
    input logic [17:0] AMOUNT,
    input logic [17:0] sr,

    output logic [17:0] out     
);

    //2 biquads that implement a 4th-order butterworth bandpass filter centered around ... kHz with a Q of ...
    //Function to implement
        //y[n]=b0​x[n]+b1​x[n−1]+b2​x[n−2]+b3​x[n−3]+b4​x[n−4]−a1​y[n−1]−a2​y[n−2]−a3​y[n−3]−a4​y[n−4]
        //Implemented using two biquads in series, where the output of the first biquad is the input to the second biquad
        //y[n]=b0​x[n]+b1​x[n−1]+b2​x[n−2]−a1​y[n−1]−a2​y[n−2]

    //Will need I think, 10 mult IPs, adders, delay reg, and subtration IPs. 

endmodule