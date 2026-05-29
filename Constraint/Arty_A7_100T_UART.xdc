## Project Name: Advanced 16550-Compatible UART Peripheral Core
## File Name:    Arty_A7_100T_UART.xdc
## Target Board: Digilent Arty A7-100T (xc7a100tcsg324-1)
## Component:    Physical Property Pin Mapping & Timing Exceptions Configuration
## 
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##     http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

## 1. System Clock (100 MHz Onboard Oscillator)
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports { clk }];
create_clock -add -name sys_clk_pin -period 10.00 -waveforms {0 5} [get_ports { clk }];

## 2. Dedicated Hardware USB-UART Interface
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33 } [get_ports { rx }]; # FPGA_RXD
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { tx }]; # FPGA_TXD

## 3. Bus Control & Reset (Mapped to Onboard Push Buttons)
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { rst }]; # BTN0
set_property -dict { PACKAGE_PIN C9    IOSTANDARD LVCMOS33 } [get_ports { wr }];  # BTN1
set_property -dict { PACKAGE_PIN B9    IOSTANDARD LVCMOS33 } [get_ports { rd }];  # BTN2

## 4. Bus Address Bits (Mapped to Onboard Slide Switches)
set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { addr[0] }]; # SW0
set_property -dict { PACKAGE_PIN L16   IOSTANDARD LVCMOS33 } [get_ports { addr[1] }]; # SW1
set_property -dict { PACKAGE_PIN M13   IOSTANDARD LVCMOS33 } [get_ports { addr[2] }]; # SW2

## 5. Parallel Data Input Bus (Mapped to Pmod Header JA)
set_property -dict { PACKAGE_PIN G13   IOSTANDARD LVCMOS33 } [get_ports { din[0] }]; # JA Pin 1
set_property -dict { PACKAGE_PIN B11   IOSTANDARD LVCMOS33 } [get_ports { din[1] }]; # JA Pin 2
set_property -dict { PACKAGE_PIN A11   IOSTANDARD LVCMOS33 } [get_ports { din[2] }]; # JA Pin 3
set_property -dict { PACKAGE_PIN D12   IOSTANDARD LVCMOS33 } [get_ports { din[3] }]; # JA Pin 4
set_property -dict { PACKAGE_PIN D13   IOSTANDARD LVCMOS33 } [get_ports { din[4] }]; # JA Pin 7
set_property -dict { PACKAGE_PIN B18   IOSTANDARD LVCMOS33 } [get_ports { din[5] }]; # JA Pin 8
set_property -dict { PACKAGE_PIN A18   IOSTANDARD LVCMOS33 } [get_ports { din[6] }]; # JA Pin 9
set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports { din[7] }]; # JA Pin 10

## 6. Parallel Data Output Bus (Mapped to Pmod Header JB)
set_property -dict { PACKAGE_PIN G14   IOSTANDARD LVCMOS33 } [get_ports { data_out[0] }]; # JB Pin 1
set_property -dict { PACKAGE_PIN P15   IOSTANDARD LVCMOS33 } [get_ports { data_out[1] }]; # JB Pin 2
set_property -dict { PACKAGE_PIN V11   IOSTANDARD LVCMOS33 } [get_ports { data_out[2] }]; # JB Pin 3
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { data_out[3] }]; # JB Pin 4
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { data_out[4] }]; # JB Pin 7
set_property -dict { PACKAGE_PIN R16   IOSTANDARD LVCMOS33 } [get_ports { data_out[5] }]; # JB Pin 8
set_property -dict { PACKAGE_PIN T13   IOSTANDARD LVCMOS33 } [get_ports { data_out[6] }]; # JB Pin 9
set_property -dict { PACKAGE_PIN U13   IOSTANDARD LVCMOS33 } [get_ports { data_out[7] }]; # JB Pin 10

## 7. Timing Exceptions for Asynchronous I/O Test Ports
set_false_path -from [get_ports {rst wr rd addr[*] din[*]}]
set_false_path -to [get_ports {data_out[*]}]