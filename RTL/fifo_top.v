// Project Name: Advanced 16550-Compatible UART Peripheral Core
// File Name:    fifo_top.v
// Architecture: AMD/Xilinx Artix-7
// Target Board: Digilent Arty A7-100T (xc7a100tcsg324-1)
// Component:    Synchronous 16-Entry x 8-Bit Circular FIFO Buffer
// 
// Description:  An optimized, synchronous FIFO memory block used for TX and RX decoupling.
//               Features synchronous pointer evaluation, safe zero-return on read-empty conditions, 
//               and programmable logic-threshold-reached tracking.
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

module fifo_top(
  input             clk,
  input             rst,
  input             fifo_en,
  input             push_en,
  input             pop_en,
  input      [7:0]  data_in,
  output     [7:0]  data_out,
  output            empty,
  output            full,
  output            overrun,
  output            underrun,
  input      [3:0]  thresh_level,
  output            thresh_reached
);

  reg [7:0] mem [0:15];

  reg [3:0] wptr  = 4'h0;
  reg [3:0] rptr  = 4'h0;
  reg [4:0] count = 5'h0;

  wire push, pop;
  reg  overrun_t, underrun_t;
  reg  thresh_t;

  assign empty         = (count == 5'd0);
  assign full          = (count == 5'd16);
  assign data_out      = empty ? 8'h00 : mem[rptr];
  assign push          = fifo_en & push_en & ~full;
  assign pop           = fifo_en & pop_en  & ~empty;
  assign overrun       = overrun_t;
  assign underrun      = underrun_t;
  assign thresh_reached = thresh_t;

  // Count
  
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      count <= 5'd0;
    else if (push && !pop)
      count <= count + 5'd1;
    else if (!push && pop)
      count <= count - 5'd1;
  end
  
  // Write pointer
  
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      wptr <= 4'h0;
    else if (push)
      wptr <= wptr + 4'h1;   // wraps naturally at 4-bit boundary
  end

  
  // Read pointer
  
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      rptr <= 4'h0;
    else if (pop)
      rptr <= rptr + 4'h1;
  end

  
  // Memory write
  
  always @(posedge clk)
    if (push)
      mem[wptr] <= data_in;

  
  // Overrun & Underrun flags
  
  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      overrun_t  <= 1'b0;
      underrun_t <= 1'b0;
    end
    else
    begin
      overrun_t  <= fifo_en & push_en & full;
      underrun_t <= fifo_en & pop_en  & empty;
    end
  end

 
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      thresh_t <= 1'b0;
    else
      thresh_t <= (count >= {1'b0, thresh_level});
  end

endmodule