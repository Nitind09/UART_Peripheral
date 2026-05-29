// Project Name: Advanced 16550-Compatible UART Peripheral Core
// File Name:    uart_top.v
// Architecture: AMD/Xilinx Artix-7
// Target Board: Digilent Arty A7-100T (xc7a100tcsg324-1)
// Component:    Top-Level System Wrapper
// 
// Description:  Integrates the complete UART ecosystem. Links the processor 
//               interface register bus map with independent TX and RX channels 
//               and their respective 16x8 circular FIFO queuing structures.
//
// Dependencies: uart_regs.v, fifo_top.v, uart_tx_top.v, uart_rx_top.v
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

module uart_top(
  input        clk,
  input        rst,
  input        wr,
  input        rd,
  input        rx,
  input  [2:0] addr,
  input  [7:0] din,
  output       tx,
  output [7:0] data_out
);

  wire        baud_pulse;
  wire        tx_fifo_push, tx_fifo_pop;
  wire        tx_fifo_reset_soft, rx_fifo_reset_soft;
  wire        rx_fifo_push, rx_fifo_pop;
  wire [7:0]  tx_fifo_out, rx_fifo_out;
  wire        tx_fifo_empty, rx_fifo_empty;
  wire        tx_shift_reg_empty;
  wire        rx_fifo_overrun, rx_fifo_underrun;
  wire [3:0]  rx_fifo_threshold;
  wire        rx_parity_error, rx_framing_error, rx_break_interrupt;
  wire [7:0]  fcr_reg, lcr_reg, lsr_reg, scr_reg;
  wire [7:0]  baud_div_lsb_reg, baud_div_msb_reg;

  wire [7:0]  rx_data_out;

  wire tx_fifo_rst = rst | tx_fifo_reset_soft;
  wire rx_fifo_rst = rst | rx_fifo_reset_soft;

  // Register block
  
  uart_regs uart_regs_inst(
    .clk              (clk),
    .rst              (rst),
    .wr_i             (wr),
    .rd_i             (rd),
    .rx_fifo_empty_i  (rx_fifo_empty),
    .rx_overrun_err   (rx_fifo_overrun),
    .rx_parity_err    (rx_parity_error),
    .rx_framing_err   (rx_framing_error),
    .rx_break_int     (rx_break_interrupt),
    .tx_fifo_empty_i  (tx_fifo_empty),
    .tx_shift_empty_i (tx_shift_reg_empty),
    .addr_i           (addr),
    .din_i            (din),
    .rx_fifo_data_in  (rx_fifo_out),
    .tx_fifo_push     (tx_fifo_push),
    .rx_fifo_pop      (rx_fifo_pop),
    .baud_pulse_out   (baud_pulse),
    .tx_fifo_reset    (tx_fifo_reset_soft),
    .rx_fifo_reset    (rx_fifo_reset_soft),
    .rx_fifo_threshold(rx_fifo_threshold),
    .data_out         (data_out),
    .fcr_out          (fcr_reg),
    .lcr_out          (lcr_reg),
    .lsr_out          (lsr_reg),
    .scr_out          (scr_reg),
    .baud_div_lsb_out (baud_div_lsb_reg),
    .baud_div_msb_out (baud_div_msb_reg)
  );

  // TX FIFO

  fifo_top tx_fifo_inst(
    .clk          (clk),
    .rst          (tx_fifo_rst),   
    .fifo_en      (1'b1),
    .push_en      (tx_fifo_push),
    .pop_en       (tx_fifo_pop),
    .data_in      (din),
    .data_out     (tx_fifo_out),
    .empty        (tx_fifo_empty),
    .full         (),
    .overrun      (),
    .underrun     (),
    .thresh_level (4'h0),
    .thresh_reached()
  );

  
  // RX FIFO
  
  fifo_top rx_fifo_inst(
    .clk          (clk),
    .rst          (rx_fifo_rst),   
    .fifo_en      (1'b1),
    .push_en      (rx_fifo_push),
    .pop_en       (rx_fifo_pop),
    .data_in      (rx_data_out),  
    .data_out     (rx_fifo_out),
    .empty        (rx_fifo_empty),
    .full         (),
    .overrun      (rx_fifo_overrun),
    .underrun     (rx_fifo_underrun),
    .thresh_level (rx_fifo_threshold),
    .thresh_reached()
  );

  
  // TX engine
  
  uart_tx_top uart_tx_inst(
    .clk            (clk),
    .rst            (rst),
    .baud_pulse     (baud_pulse),
    .parity_en      (lcr_reg[3]),
    .tx_fifo_empty  (tx_fifo_empty),
    .stop_bit_sel   (lcr_reg[2]),
    .sticky_parity  (lcr_reg[5]),   // LCR[5] = stick parity
    .even_parity_sel(lcr_reg[4]),   // LCR[4] = even parity select
    .set_break      (lcr_reg[6]),
    .data_in        (tx_fifo_out),
    .word_len_sel   (lcr_reg[1:0]),
    .pop            (tx_fifo_pop),
    .shift_reg_empty(tx_shift_reg_empty),
    .tx             (tx)
  );

 
  // RX engine
  
  uart_rx_top uart_rx_inst(
    .clk            (clk),
    .rst            (rst),
    .baud_pulse     (baud_pulse),
    .rx             (rx),
    .sticky_parity  (lcr_reg[5]),
    .even_parity_sel(lcr_reg[4]),
    .parity_en      (lcr_reg[3]),
    .word_len_sel   (lcr_reg[1:0]),
    .push           (rx_fifo_push),
    .parity_error   (rx_parity_error),
    .framing_error  (rx_framing_error),
    .break_interrupt(rx_break_interrupt),
    .data_out       (rx_data_out)    
  );

endmodule