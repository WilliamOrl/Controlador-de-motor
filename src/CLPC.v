

//IMPORTED MODULE:demux2
module demux2(
  input wire in, select,
  output reg outa, outb
);
  assign outa = in & ~select;
  assign outb = in & select;
endmodule



//IMPORTED MODULE:adder16signed
module adder16signed(na, nb, no);
  input wire signed [15:0] na, nb;
  output reg signed [15:0] no;
  
  assign  no = na + nb;
endmodule



//IMPORTED MODULE:debouncer
module debouncer(
  input wire clock, 
  input wire button, 
  output reg butout
);
  
  reg [15:0] counter;
  reg [15:0] reference;
  initial butout = 0;
  initial counter = 0;
  initial reference = 16'b1111111111111111;
  
  always @(negedge clock) begin
    counter <= counter + 1;
    if (counter == reference) begin
      counter <= 0;
    end else begin
      butout <= button;
    end
  end
  
endmodule



//IMPORTED MODULE:subtractor16signed
module subtractor16signed (np, nn, no);
  input wire signed [15:0] np, nn;
  output reg signed [15:0] no;
  
  assign no = np - nn;
endmodule



//IMPORTED MODULE:greater16signed
module greater16signed (na, nb, out);
  input wire signed [15:0] na, nb;
  output reg out;
  
  always @* begin
    if (na > nb) out = 1;
    else out = 0;
  end
endmodule



//IMPORTED MODULE:gain16signed
module gain16signed (na, nb, no);

//-----------Input Ports---------------- 
  input wire signed [15:0] na, nb; 

//-----------Output Ports--------------- 
  output reg signed [15:0] no; 

//-------------Code Start---------------
  assign no = na * nb;

endmodule



//IMPORTED MODULE:encoder
module encoder (clock, quadA, quadB, counter); 
  input wire clock, quadA, quadB; 
  output reg signed [15:0] counter; 
  
  initial counter = 0;
  
  reg [2:0] quadA_delayed, quadB_delayed; 
  
  always @(posedge clock) quadA_delayed <= {quadA_delayed[1:0], quadA}; 
  always @(posedge clock) quadB_delayed <= {quadB_delayed[1:0], quadB}; 
  
  wire count_enable = quadA_delayed[1] ^ quadA_delayed[2] ^ quadB_delayed[1] ^ quadB_delayed[2]; 
  wire count_direction = quadA_delayed[1] ^ quadB_delayed[2]; 
  
  always @(posedge clock) begin 
    if(count_enable) begin 
      if(count_direction) counter<=counter+1; 
      else counter<=counter-1; 
    end 
  end 
endmodule



//IMPORTED MODULE:pulse_count16
module pulse_count16(pulse, counter);
  input wire pulse;
  output reg [15:0] counter;
  
  initial counter = 0;
  
  always @(posedge pulse) begin
    counter <= counter + 1;
  end
endmodule



//IMPORTED MODULE:one_hz_clock
`define clock_frequnecy 27_000_000
module one_hz_clock #(parameter DELAY = 1000)(input clk,            // clk input
								output reg out);  // output pin

  localparam TICKS = DELAY * (`clock_frequnecy / 2000);

  reg [26:0] counter = 0;
  
  initial out = 1;
  
    always @(posedge clk) begin
    	counter <= counter + 1'b1;
    	if (counter == TICKS) begin
    		out <= ~out;
    		counter <= 27'b0;
    	end
    end
endmodule




//IMPORTED MODULE:uart_tx_16_bit_dec_trigger
`define clock_frequency 27_000_000

module bin2bcd #(parameter W = 8) (bin, bcd);

	input [W-1:0] bin;  			// Binary data in
	output reg [W+(W-4)/3:0] bcd; 	// BCD data out {...,thousands,hundreds,tens,ones}

	integer i,j;

	always @(bin) begin
		for(i = 0; i <= W+(W-4)/3; i = i+1) bcd[i] = 0;     		// initialize with zeros
		bcd[W-1:0] = bin;                                   		// initialize with input vector
		for(i = 0; i <= W-4; i = i+1)                       		// iterate on structure depth
			for(j = 0; j <= i/3; j = j+1)                     		// iterate on structure width
				if (bcd[W-i+4*j -: 4] > 4)                      	// if > 4
          			bcd[W-i+4*j -: 4] = bcd[W-i+4*j -: 4] + 4'd3; 	// add 3
  end

endmodule


// Transmits the input data formatted as a decimal number, for example 0xA1B2 or 0b1010 0001 1011 0010 would be trasnmitted as "41394"  
// This variation transmits on a positive edge of the inTrigger signal.
module uart_tx_16_bit_dec_trigger #(parameter BAUD_RATE = 115200, parameter SEP_CHAR = " ") (clk, inData, separator, inTrigger, uartTxPin, txDone);

	localparam DELAY_FRAMES = (`clock_frequency/BAUD_RATE);
	localparam HALF_DELAY_WAIT = (DELAY_FRAMES / 2);

	input clk;				// System clock
	input [0:15] inData;		// Input byte to me transmitted
	input separator;		// Separator input - Adds the SEP_CHAR character between each trasnmission (usually " " or " ")
	input inTrigger;		// Trigger input - Active high
	output reg uartTxPin;	// TX pin
	output reg txDone;		// Transmission finished flag - Low while transmitting

	initial begin
	    uartTxPin = 1'b1;
	    txDone = 1'b1;
	end
	
	reg [3:0] txState = 0;
	reg [24:0] txCounter = 0;
	reg [7:0] dataOut = 0;
	reg [2:0] txBitNumber = 0;
	reg [4:0] txByteCounter = 0;

	// Number_of_bits = 20 = W+(W-4)/3 -> where W is the number of bits of the data to be converted (16 in this case)
	reg [19 : 0] BcdMemory;
	bin2bcd #(16) BinToBCD (.bin(inData), .bcd(BcdMemory));

	localparam MEMORY_LENGTH = 6; // "_65535" counting the separator character
	reg [7:0] txData [MEMORY_LENGTH-1:0];

	localparam TX_STATE_IDLE = 0;
	localparam TX_STATE_START_BIT = 1;
	localparam TX_STATE_WRITE = 2;
	localparam TX_STATE_STOP_BIT = 3;
	localparam TX_STATE_DEBOUNCE = 4;

	always @(posedge clk) begin
		case (txState)
			TX_STATE_IDLE: begin
				if (inTrigger == 1) begin
					txState <= TX_STATE_START_BIT;
					txCounter <= 0;
					txData[0] <= SEP_CHAR;
					txData[1] <= BcdMemory[19:16] + 8'd48;
					txData[2] <= BcdMemory[15:12] + 8'd48;
					txData[3] <= BcdMemory[11:8] + 8'd48;
					txData[4] <= BcdMemory[7:4] + 8'd48;
					txData[5] <= BcdMemory[3:0] + 8'd48;
					if(separator) txByteCounter <= 0;
					else txByteCounter <= 1;
				end
				else begin
					uartTxPin <= 1;
					txDone <= 1;
				end
			end 
			TX_STATE_START_BIT: begin
				uartTxPin <= 0;
				txDone <= 0;
				if ((txCounter + 1) == DELAY_FRAMES) begin
					txState <= TX_STATE_WRITE;
					dataOut <= txData[txByteCounter];
					txBitNumber <= 0;
					txCounter <= 0;
				end else 
					txCounter <= txCounter + 1;
			end
			TX_STATE_WRITE: begin
				uartTxPin <= dataOut[txBitNumber];
				if ((txCounter + 1) == DELAY_FRAMES) begin
					if (txBitNumber == 3'b111) begin
						txState <= TX_STATE_STOP_BIT;
					end else begin
						txState <= TX_STATE_WRITE;
						txBitNumber <= txBitNumber + 1;
					end
					txCounter <= 0;
				end else 
					txCounter <= txCounter + 1;
			end
			TX_STATE_STOP_BIT: begin
				uartTxPin <= 1;
				txDone <= 1;
				if ((txCounter + 1) == DELAY_FRAMES) begin
					if (txByteCounter == MEMORY_LENGTH - 1) begin
						txState <= TX_STATE_DEBOUNCE;
					end else begin
						txByteCounter <= txByteCounter + 1;
						txState <= TX_STATE_START_BIT;
					end
					txCounter <= 0;
				end else 
					txCounter <= txCounter + 1;
			end
			TX_STATE_DEBOUNCE: begin
				if (inTrigger == 0)
					txState <= TX_STATE_IDLE;
				else
					txState <= TX_STATE_DEBOUNCE;
			end
		endcase      
	end
endmodule




// Automatically generated by ChipInventor Cloud EDA Tool - 3.08
// Careful: this file (hdl.v) will be automatically replaced when you ask
// to generate code from BLOCKS buttons.
module top (

  input wire clk,
  input wire key,
  input wire rst,
  input wire IO48,
  input wire IO49,
  output wire IO31,
  output wire IO32,
  output wire uartTx,
  output wire TxDone

);

//Internal Wires
 wire w_1;
 wire [15:0] w_2;
 wire w_3;
 wire [15:0] w_4;
 wire [15:0] w_5;
 wire [15:0] w_6;
 wire [15:0] w_7;
 wire [15:0] w_8;
 wire w_9;
 wire w_11;

//Instances os Modules
pulse_count16 blk79_9 (
         .pulse (w_1),
         .counter (w_2)
     );

pulse_count16 blk79_10 (
         .pulse (w_3),
         .counter (w_4)
     );

subtractor16signed blk68_11 (
         .np (w_2),
         .nn (w_4),
         .no (w_5)
     );

gain16signed blk71_13 (
         .nb (100),
         .na (w_5),
         .no (w_6)
     );

adder16signed blk41_14 (
         .nb (w_6),
         .na (w_7),
         .no (w_8)
     );

greater16signed blk70_15 (
         .nb (0),
         .na (w_8),
         .out (w_9)
     );

encoder blk72_31 (
         .clock (clk),
         .quadA (IO48),
         .quadB (IO49),
         .counter (w_7)

     );

debouncer blk42_34 (
         .clock (clk),
         .button (key),
         .butout (w_1)
     );

debouncer blk42_35 (
         .clock (clk),
         .button (rst),
         .butout (w_3)
     );

demux2 blk39_40 (
         .outa (IO31),
         .outb (IO32),
         .in (1),
         .select (w_9)
     );

one_hz_clock blk80_77 (
         .clk (clk),
         .out (w_11)
     );

uart_tx_16_bit_dec_trigger blk150_80 (
         .clk (clk),
         .uartTxPin (uartTx),
         .txDone (TxDone),
         .separator (0),
         .inData (w_7),
         .inTrigger (w_11)
     );


endmodule

