// Project Name: Advanced 16550-Compatible UART Peripheral Core
// File Name:    uart_tx_top.v
// Architecture: AMD/Xilinx Artix-7
// Target Board: Digilent Arty A7-100T (xc7a100tcsg324-1)
// Component:    UART Serial Transmitter Engine (TX)
// 
// Description:  Finite State Machine managing parallel-to-serial data conversion. 
//               Handles dynamic payload sizes (5 to 8 bits), configurable parity 
//               generation (even, odd, or stick), and fractional stop bit budgeting.
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

module uart_tx_top(
  input             clk,
  input             rst,
  input             baud_pulse,
  input             parity_en,
  input             tx_fifo_empty,
  input             stop_bit_sel,
  input             sticky_parity,
  input             even_parity_sel,
  input             set_break,
  input      [7:0]  data_in,
  input      [1:0]  word_len_sel,
  output reg        pop,
  output reg        shift_reg_empty,
  output reg        tx
);

  // FSM states
  localparam ST_IDLE  = 2'b00;
  localparam ST_START = 2'b01;
  localparam ST_DATA  = 2'b10;
  localparam ST_PAR   = 2'b11;

  reg [1:0]  state        = ST_IDLE;
  reg [7:0]  shift_reg    = 8'h00;
  reg [7:0]  data_in_reg;
  reg        tx_bit       = 1'b1;
  reg        data_parity;
  reg        parity_bit;
  reg [2:0]  bit_counter  = 3'd0;
  reg [4:0]  baud_counter = 5'd0;

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      state          <= ST_IDLE;
      baud_counter   <= 5'd0;      
      bit_counter    <= 3'd0;
      shift_reg      <= 8'h00;     
      pop            <= 1'b0;
      shift_reg_empty <= 1'b1;     
      tx_bit         <= 1'b1;
      data_parity    <= 1'b0;
      parity_bit     <= 1'b0;
    end
    else if (baud_pulse)
    begin
      case (state)
        ST_IDLE:
        begin
          pop <= 1'b0;

          if (!tx_fifo_empty)
          begin
            if (baud_counter != 5'd0)
            begin
              baud_counter <= baud_counter - 5'd1;
            end
            else
            begin
              // Latch data, start the frame
              data_in_reg    <= data_in;
              shift_reg      <= data_in;
              baud_counter   <= 5'd15;
              bit_counter    <= {1'b1, word_len_sel}; 
              pop            <= 1'b1;          // pop FIFO
              shift_reg_empty <= 1'b0;
              tx_bit         <= 1'b0;          // start bit (low)
              state          <= ST_START;
            end
          end
        end

        
        ST_START:
        begin
          pop <= 1'b0;   
          case (word_len_sel)
            2'b00: data_parity <= ^data_in_reg[4:0];
            2'b01: data_parity <= ^data_in_reg[5:0];
            2'b10: data_parity <= ^data_in_reg[6:0];
            2'b11: data_parity <= ^data_in_reg[7:0];
          endcase

          if (baud_counter != 5'd0)
            baud_counter <= baud_counter - 5'd1;
          else
          begin
            baud_counter <= 5'd15;
            tx_bit       <= shift_reg[0];  
            shift_reg    <= shift_reg >> 1;
            state        <= ST_DATA;
          end
        end

        
        ST_DATA:
        begin
          if (baud_counter != 5'd0)
            baud_counter <= baud_counter - 5'd1;
          else
          begin
            if (bit_counter != 3'd0)
            begin
              baud_counter <= 5'd15;
              bit_counter  <= bit_counter - 3'd1;
              tx_bit       <= shift_reg[0];
              shift_reg    <= shift_reg >> 1;
              
            end
            else
            begin
              
              shift_reg_empty <= 1'b1;

              
              case ({sticky_parity, even_parity_sel})
                2'b00: parity_bit <= ~data_parity; // odd
                2'b01: parity_bit <=  data_parity; // even
                2'b10: parity_bit <=  1'b1;        // stick 1
                2'b11: parity_bit <=  1'b0;        // stick 0
              endcase

              if (parity_en)
              begin
                baud_counter <= 5'd15;
                tx_bit       <= (sticky_parity ? even_parity_sel ? 1'b0 : 1'b1
                                               : even_parity_sel ? data_parity
                                                                  : ~data_parity);
                state        <= ST_PAR;
              end
              else
              begin
                
                baud_counter <= stop_bit_sel ? (word_len_sel == 2'b00 ? 5'd23 : 5'd31)
                                             : 5'd15;
                tx_bit <= 1'b1;  
                state  <= ST_IDLE;
              end
            end
          end
        end

        
        ST_PAR:
        begin
          if (baud_counter != 5'd0)
            baud_counter <= baud_counter - 5'd1;
          else
          begin
            
            baud_counter <= stop_bit_sel ? (word_len_sel == 2'b00 ? 5'd23 : 5'd31)
                                         : 5'd15;
            tx_bit <= 1'b1;  // stop bit
            state  <= ST_IDLE;
          end
        end

        default: state <= ST_IDLE;

      endcase
    end
  end

  
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      tx <= 1'b1;
    else
      tx <= set_break ? 1'b0 : tx_bit;
  end

endmodule