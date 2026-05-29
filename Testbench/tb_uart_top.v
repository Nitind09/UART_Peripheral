// Project Name: Advanced 16550-Compatible UART Peripheral Core
// File Name:    tb_uart_top.v
// Architecture: Simulation Testbench Environment
// Component:    System Loopback Simulation Top
// 
// Description:  Comprehensive behavioral verification suite for the system top.
//               Drives parallel bus tasks (write_reg/read_reg) while capturing data over 
//               a hardware-isolated serial digital loopback (TX wired directly to RX).
//
// Dependencies: uart_top.v
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

module tb_uart_top;

  
  // Signal Declarations
  
  reg        clk;
  reg        rst;
  reg        wr;
  reg        rd;
  reg [2:0]  addr;
  reg [7:0]  din;
  
  wire       tx;
  wire       rx;
  wire [7:0] data_out;

  // Testbench internal tracking variables
  integer    error_count;
  reg [7:0]  rdata;
  integer    timeout;

  
  // DUT Instantiation & External Loopback Connection
  
  assign rx = tx; 

  uart_top uut (
    .clk(clk),
    .rst(rst),
    .wr(wr),
    .rd(rd),
    .rx(rx),
    .addr(addr),
    .din(din),
    .tx(tx),
    .data_out(data_out)
  );

  
  // Clock Generation (50 MHz Clock -> 20ns Period)
  
  always begin
    clk = 1'b0;
    #10;
    clk = 1'b1;
    #10;
  end

  
  // Helper Tasks for Register Bus Interfaces
  
  task write_reg;
    input [2:0] r_addr;
    input [7:0] r_data;
    begin
      @(posedge clk);
      addr = r_addr;
      din  = r_data;
      wr   = 1'b1;
      rd   = 1'b0;
      @(posedge clk);
      wr   = 1'b0;
      #1; 
    end
  endtask

  task read_reg;
    input [2:0]  r_addr;
    output [7:0] r_data;
    begin
      @(posedge clk);
      addr   = r_addr;
      wr     = 1'b0;
      rd     = 1'b1;
      @(posedge clk);
      #1; 
      r_data = data_out;
      rd     = 1'b0;
      #1;
    end
  endtask

  
  // Main Test Stimulus
  
  initial begin
    rst         = 1'b1;
    wr          = 1'b0;
    rd          = 1'b0;
    addr        = 3'b000;
    din         = 8'h00;
    error_count = 0;
    timeout     = 0;

    $display("==================================================");
    $display("Starting UART Peripheral Self-Testing Testbench...");
    $display("==================================================");

    #100;
    @(posedge clk);
    rst = 1'b0;
    $display("[TB] System Reset released.");
    #40;

    $display("[TB] Step 1: Testing Scratchpad Register (SCR)...");
    write_reg(3'h7, 8'hA5);
    read_reg(3'h7, rdata);
    if (rdata !== 8'hA5) begin
      $display("[ERROR] SCR read mismatch! Wrote: 0xA5, Read: 0x%h", rdata);
      error_count = error_count + 1;
    end else begin
      $display("[PASS] SCR basic write/read successful.");
    end

    $display("[TB] Step 2: Configuring Baud Rate Divisor...");
    write_reg(3'h3, 8'h80); 
    write_reg(3'h0, 8'h02); 
    write_reg(3'h1, 8'h00); 

    $display("[TB] Step 3: Setting Frame Format (8N1)...");
    write_reg(3'h3, 8'h03); 

    $display("[TB] Step 4: Enabling Transmit & Receive FIFOs...");
    write_reg(3'h2, 8'h01); 
    #100;

    $display("[TB] Step 5: Transmitting Test Byte (0x5A) via loopback...");
    write_reg(3'h0, 8'h5A); 

    $display("[TB] Step 6: Polling LSR for Data Ready flag...");
    read_reg(3'h5, rdata);
    timeout = 0;
    
    while (((rdata & 8'h01) == 0) && (timeout < 5000)) begin
      #100;
      read_reg(3'h5, rdata);
      timeout = timeout + 1;
    end

    if (timeout >= 5000) begin
      $display("[ERROR] Timeout waiting for LSR Data Ready flag! Loopback failed.");
      error_count = error_count + 1;
    end else begin
      $display("[TB] LSR Data Ready detected! Proceeding to read...");
      
     
      read_reg(3'h0, rdata); 
      
      $display("[TB] Received Data Byte: 0x%h", rdata);
      if (rdata !== 8'h5A) begin
        $display("[ERROR] Payload mismatch! Expected: 0x5A, Got: 0x%h", rdata);
        error_count = error_count + 1;
      end else begin
        $display("[PASS] Data byte matched loopback payload successfully.");
      end
    end

    $display("==================================================");
    if (error_count == 0) begin
      $display("  >>>> ALL TESTS PASSED SUCCESSFULLY! <<<<  ");
    end else begin
      $display("  >>>> TESTBENCH FAILED With %d Errors. <<<<  ", error_count);
    end
    $display("==================================================");

    $finish;
  end

endmodule