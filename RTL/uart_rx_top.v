// Project Name: Advanced 16550-Compatible UART Peripheral Core
// File Name:    uart_rx_top.v
// Architecture: AMD/Xilinx Artix-7
// Target Board: Digilent Arty A7-100T (xc7a100tcsg324-1)
// Component:    UART Serial Receiver Engine (RX)
// 
// Description:  Asynchronous serial-to-parallel data receiver interface. Runs a 
//               16x oversampling engine to recover frames while checking structural boundary 
//               integrity for parity, framing, and line break exceptions.
//
// Dependencies: None (Leaf cell module)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

`timescale 1ns / 1ps

module uart_rx_top(
  input             clk,
  input             rst,
  input             baud_pulse,
  input             rx,
  input             sticky_parity,
  input             even_parity_sel,
  input             parity_en,
  input      [1:0]  word_len_sel,
  output reg        push,
  output reg        parity_error,
  output reg        framing_error,
  output reg        break_interrupt,
  output reg [7:0]  data_out
);

  // FSM states
  localparam ST_IDLE  = 3'b000;
  localparam ST_START = 3'b001;
  localparam ST_DATA  = 3'b010;
  localparam ST_PAR   = 3'b011;
  localparam ST_STOP  = 3'b100;

  reg [2:0] state = ST_IDLE;

  
  reg rx_sync1 = 1'b1;
  reg rx_sync  = 1'b1;
  
          // Compute expected parity over the relevant data bits
  reg [7:0] masked_data;

  always @(posedge clk or posedge rst)
    if (rst) begin rx_sync1 <= 1'b1; rx_sync <= 1'b1; end
    else     begin rx_sync1 <= rx;   rx_sync <= rx_sync1; end

 
  wire start_detected = ~rx_sync;


  reg [4:0] baud_counter = 5'd0;

  reg [2:0] bit_counter  = 3'd0;

  reg       parity_calc;   // computed expected parity

  
  // Main FSM

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      state           <= ST_IDLE;
      push            <= 1'b0;
      parity_error    <= 1'b0;
      framing_error   <= 1'b0;
      break_interrupt <= 1'b0;
      baud_counter    <= 5'd0;
      bit_counter     <= 3'd0;
      data_out        <= 8'h00;
      parity_calc     <= 1'b0;
    end
    else
    begin
      push <= 1'b0;   // default: de-assert push every cycle

      if (baud_pulse)
      begin
        case (state)

          
          // IDLE - wait for start bit (falling edge on RX)
          
          ST_IDLE:
          begin
            if (start_detected)
            begin
              // Sample in the middle of start bit = 7 baud-pulses from now
              baud_counter <= 5'd7;
              state        <= ST_START;
            end
          end

          
          // START BIT - verify it is still low at the mid-point
         
          ST_START:
          begin
            if (baud_counter != 5'd0)
              baud_counter <= baud_counter - 5'd1;
            else
            begin
              if (rx_sync == 1'b1)
              begin
               
                state <= ST_IDLE;
              end
              else
              begin
               
                baud_counter <= 5'd15;
               
                bit_counter  <= {1'b1, word_len_sel}; 
                state        <= ST_DATA;
              end
            end
          end

          
          // DATA BITS - shift in LSB-first
          
          ST_DATA:
          begin
            if (baud_counter != 5'd0)
              baud_counter <= baud_counter - 5'd1;
            else
            begin
              
              case (word_len_sel)
                2'b00: data_out <= {3'b000, rx_sync, data_out[4:1]};
                2'b01: data_out <= {2'b00,  rx_sync, data_out[5:1]};
                2'b10: data_out <= {1'b0,   rx_sync, data_out[6:1]};
                2'b11: data_out <= {        rx_sync, data_out[7:1]};
              endcase

              baud_counter <= 5'd15;

              if (bit_counter != 3'd0)
                bit_counter <= bit_counter - 3'd1;
              else
              begin
                
                if (parity_en)
                  state <= ST_PAR;
                else
                  state <= ST_STOP;
              end
            end
          end

          
          ST_PAR:
          begin
            if (baud_counter != 5'd0) begin
              baud_counter <= baud_counter - 5'd1;
            end
            else begin

              case (word_len_sel)
                2'b00: masked_data = {3'b000, data_out[4:0]};
                2'b01: masked_data = {2'b00,  data_out[5:0]};
                2'b10: masked_data = {1'b0,   data_out[6:0]};
                2'b11: masked_data =          data_out;
              endcase

              case ({sticky_parity, even_parity_sel})
                2'b00: parity_calc = ~^masked_data; // odd  parity expected
                2'b01: parity_calc =  ^masked_data; // even parity expected
                2'b10: parity_calc =  1'b1;         // stick=1, expected rx=1
                2'b11: parity_calc =  1'b0;         // stick=0, expected rx=0
              endcase

              parity_error <= (rx_sync != parity_calc);

              baud_counter <= 5'd15;
              state        <= ST_STOP;
            end
          end

         
          ST_STOP:
          begin
            if (baud_counter != 5'd0)
              baud_counter <= baud_counter - 5'd1;
            else
            begin
              framing_error <= ~rx_sync;   

              
              break_interrupt <= (~rx_sync) & (data_out == 8'h00);

              push  <= 1'b1;
              state <= ST_IDLE;
            end
          end

          default: state <= ST_IDLE;

        endcase
      end
    end
  end

endmodule