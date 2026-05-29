// Project Name: Advanced 16550-Compatible UART Peripheral Core
// File Name:    uart_regs.v
// Architecture: AMD/Xilinx Artix-7
// Target Board: Digilent Arty A7-100T (xc7a100tcsg324-1)
// Component:    Bus Register Interface & Configuration Map
// 
// Description:  Implements a 16550-compatible subset register map (LCR, LSR, FCR, etc.).
//               Features fully combinatorial read-back paths to prevent multi-cycle stale 
//               bus hazards and handles sticky error latching cleared on read.
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

module uart_regs(
  input             clk,
  input             rst,
  input             wr_i,
  input             rd_i,

  // Status inputs from RX path
  input             rx_fifo_empty_i,
  input             rx_overrun_err,
  input             rx_parity_err,
  input             rx_framing_err,
  input             rx_break_int,

  // Status inputs from TX path  
  input             tx_fifo_empty_i,
  input             tx_shift_empty_i,

  input      [2:0]  addr_i,
  input      [7:0]  din_i,
  input      [7:0]  rx_fifo_data_in,

  output            tx_fifo_push,
  output            rx_fifo_pop,
  output            baud_pulse_out,
  output            tx_fifo_reset,
  output            rx_fifo_reset,
  output     [3:0]  rx_fifo_threshold,
  output reg [7:0]  data_out,

  output     [7:0]  fcr_out,
  output     [7:0]  lcr_out,
  output     [7:0]  lsr_out,
  output     [7:0]  scr_out,
  output     [7:0]  baud_div_lsb_out,
  output     [7:0]  baud_div_msb_out
);

  
  // FCR  (addr 2, write-only)
  
  reg [1:0] fcr_rx_trigger_level;
  reg       fcr_dma_enable;
  reg       fcr_tx_reset;
  reg       fcr_rx_reset;
  reg       fcr_fifo_enable;

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      fcr_rx_trigger_level <= 2'b00;
      fcr_dma_enable       <= 1'b0;
      fcr_tx_reset         <= 1'b0;
      fcr_rx_reset         <= 1'b0;
      fcr_fifo_enable      <= 1'b0;
    end
    else if (wr_i && addr_i == 3'h2)
    begin
      fcr_rx_trigger_level <= din_i[7:6];
      fcr_dma_enable       <= din_i[3];
      fcr_tx_reset         <= din_i[2];
      fcr_rx_reset         <= din_i[1];
      fcr_fifo_enable      <= din_i[0];
    end
    else
    begin
      fcr_tx_reset <= 1'b0;
      fcr_rx_reset <= 1'b0;
    end
  end

  assign tx_fifo_reset = fcr_tx_reset;
  assign rx_fifo_reset = fcr_rx_reset;

  // RX threshold decode
  reg [3:0] rx_fifo_threshold_count;
  always @(*)
  begin
    if (!fcr_fifo_enable)
      rx_fifo_threshold_count = 4'd1;
    else
      case (fcr_rx_trigger_level)
        2'b00: rx_fifo_threshold_count = 4'd1;
        2'b01: rx_fifo_threshold_count = 4'd4;
        2'b10: rx_fifo_threshold_count = 4'd8;
        2'b11: rx_fifo_threshold_count = 4'd14;
      endcase
  end
  assign rx_fifo_threshold = rx_fifo_threshold_count;

  // LCR  (addr 3)

  reg       lcr_divisor_latch_access;
  reg       lcr_break_control;
  reg       lcr_stick_parity;
  reg       lcr_even_parity_select;
  reg       lcr_parity_enable;
  reg       lcr_stop_bits;
  reg [1:0] lcr_word_length_select;

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      lcr_divisor_latch_access <= 1'b0;
      lcr_break_control        <= 1'b0;
      lcr_stick_parity         <= 1'b0;
      lcr_even_parity_select   <= 1'b0;
      lcr_parity_enable        <= 1'b0;
      lcr_stop_bits            <= 1'b0;
      lcr_word_length_select   <= 2'b11;  // default 8-bit
    end
    else if (wr_i && addr_i == 3'h3)
    begin
      lcr_divisor_latch_access <= din_i[7];
      lcr_break_control        <= din_i[6];
      lcr_stick_parity         <= din_i[5];
      lcr_even_parity_select   <= din_i[4];
      lcr_parity_enable        <= din_i[3];
      lcr_stop_bits            <= din_i[2];
      lcr_word_length_select   <= din_i[1:0];
    end
  end

  
  // LSR  (addr 5, read-only; error flags sticky, cleared on LSR read)
  
  reg lsr_rx_fifo_error;
  reg lsr_break_interrupt;
  reg lsr_framing_error;
  reg lsr_parity_error;
  reg lsr_overrun_error;
  reg lsr_data_ready;

  wire lsr_read = (rd_i && addr_i == 3'h5);

  wire lsr_transmitter_empty          = tx_shift_empty_i;
  wire lsr_transmitter_holding_empty  = tx_fifo_empty_i;

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      lsr_data_ready      <= 1'b0;
      lsr_overrun_error   <= 1'b0;
      lsr_parity_error    <= 1'b0;
      lsr_framing_error   <= 1'b0;
      lsr_break_interrupt <= 1'b0;
      lsr_rx_fifo_error   <= 1'b0;
    end
    else
    begin
      lsr_data_ready <= ~rx_fifo_empty_i;

      
      if (rx_overrun_err)   lsr_overrun_error   <= 1'b1;
      else if (lsr_read)    lsr_overrun_error   <= 1'b0;

      if (rx_parity_err)    lsr_parity_error    <= 1'b1;
      else if (lsr_read)    lsr_parity_error    <= 1'b0;

      if (rx_framing_err)   lsr_framing_error   <= 1'b1;
      else if (lsr_read)    lsr_framing_error   <= 1'b0;

      if (rx_break_int)     lsr_break_interrupt <= 1'b1;
      else if (lsr_read)    lsr_break_interrupt <= 1'b0;

      if (rx_parity_err || rx_framing_err || rx_break_int)
                            lsr_rx_fifo_error   <= 1'b1;
      else if (lsr_read)    lsr_rx_fifo_error   <= 1'b0;
    end
  end

  // SCR  (addr 7)
 
  reg [7:0] scratch_reg;
  always @(posedge clk or posedge rst)
  begin
    if (rst)
      scratch_reg <= 8'h00;
    else if (wr_i && addr_i == 3'h7)
      scratch_reg <= din_i;
  end

  
  // Baud Rate Divider  (DLAB=1: addr 0 = DLL, addr 1 = DLM)
  
  reg [7:0] baud_div_lsb;
  reg [7:0] baud_div_msb;

  always @(posedge clk or posedge rst)
    if (rst)
      baud_div_lsb <= 8'h00;
    else if (wr_i && addr_i == 3'h0 && lcr_divisor_latch_access)
      baud_div_lsb <= din_i;

  always @(posedge clk or posedge rst)
    if (rst)
      baud_div_msb <= 8'h00;
    else if (wr_i && addr_i == 3'h1 && lcr_divisor_latch_access)
      baud_div_msb <= din_i;

  // Baud counter
  // baud_update fires the clock AFTER the DLL/DLM write, so the reload
  // picks up the freshly stored value correctly.
  reg        baud_update;
  reg [15:0] baud_counter;
  reg        baud_pulse;

  always @(posedge clk or posedge rst)
    if (rst)
      baud_update <= 1'b0;
    else
      baud_update <= wr_i & lcr_divisor_latch_access &
                     ((addr_i == 3'h0) | (addr_i == 3'h1));

  always @(posedge clk or posedge rst)
  begin
    if (rst)
      baud_counter <= 16'h0000;
    else if (baud_update || baud_counter == 16'h0000)
      baud_counter <= {baud_div_msb, baud_div_lsb};
    else
      baud_counter <= baud_counter - 16'd1;
  end

  always @(posedge clk or posedge rst)
    if (rst)
      baud_pulse <= 1'b0;
    else
      baud_pulse <= (|{baud_div_msb, baud_div_lsb}) & (baud_counter == 16'h0000);

  assign baud_pulse_out = baud_pulse;

  
  // TX / RX FIFO access strobes
  
  assign tx_fifo_push = wr_i & (addr_i == 3'h0) & ~lcr_divisor_latch_access;
  assign rx_fifo_pop  = rd_i & (addr_i == 3'h0) & ~lcr_divisor_latch_access;

  // RX data register (holds data popped from RX FIFO)
  reg [7:0] rx_data;
  always @(posedge clk or posedge rst)
    if (rst)
      rx_data <= 8'h00;
    else if (rx_fifo_pop)
      rx_data <= rx_fifo_data_in;

 
  always @(*)
  begin
    case (addr_i)
      3'h0: data_out = lcr_divisor_latch_access ? baud_div_lsb : rx_data;
      3'h1: data_out = lcr_divisor_latch_access ? baud_div_msb : 8'h00;
      3'h2: data_out = 8'h00;   // IIR (not implemented)
      3'h3: data_out = {lcr_divisor_latch_access, lcr_break_control,
                        lcr_stick_parity, lcr_even_parity_select,
                        lcr_parity_enable, lcr_stop_bits,
                        lcr_word_length_select};
      3'h4: data_out = 8'h00;   // MCR (not implemented)
      3'h5: data_out = {lsr_rx_fifo_error,
                        lsr_transmitter_empty,
                        lsr_transmitter_holding_empty,
                        lsr_break_interrupt,
                        lsr_framing_error,
                        lsr_parity_error,
                        lsr_overrun_error,
                        lsr_data_ready};
      3'h6: data_out = 8'h00;   // MSR (not implemented)
      3'h7: data_out = scratch_reg;
      default: data_out = 8'h00;
    endcase
  end

  // Output assignments
  
  assign fcr_out         = {fcr_rx_trigger_level, 2'b00, fcr_dma_enable,
                             fcr_tx_reset, fcr_rx_reset, fcr_fifo_enable};
  assign lcr_out         = {lcr_divisor_latch_access, lcr_break_control,
                             lcr_stick_parity, lcr_even_parity_select,
                             lcr_parity_enable, lcr_stop_bits,
                             lcr_word_length_select};
  assign lsr_out         = {lsr_rx_fifo_error,
                             lsr_transmitter_empty,
                             lsr_transmitter_holding_empty,
                             lsr_break_interrupt,
                             lsr_framing_error,
                             lsr_parity_error,
                             lsr_overrun_error,
                             lsr_data_ready};
  assign scr_out         = scratch_reg;
  assign baud_div_lsb_out = baud_div_lsb;
  assign baud_div_msb_out = baud_div_msb;

endmodule