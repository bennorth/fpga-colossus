------------------------------------------------------------------------------
--
-- Copyright 2016 Ben North
--
-- This file is part of "FPGA Colossus".
--
-- "FPGA Colossus" is free software: you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by the Free
-- Software Foundation, either version 3 of the License, or (at your option) any
-- later version.
--
-- "FPGA Colossus" is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
-- more details.
--
-- You should have received a copy of the GNU General Public License along with
-- "FPGA Colossus".  If not, see <http://www.gnu.org/licenses/>.
--
------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

------------------------------------------------------------------------------

-- The interface to the controlling RPi consists of:
--
-- RPi to FPGA: a muxd 8-bit address/data input bus (with selector line);
-- FPGA to RPi: an 8-bit response bus plus a 1-bit 'error' line.
--
-- To send a command to the FPGA, the RPi follows this protocol:
--
-- Put the command's address on 'data_addr_muxd'; set 'data_addr_sel' to '0'.
--
-- Set 'req' = '1'; wait for 'busy_out' = '1'; set 'req' = '0' (at this falling
-- edge of 'req' the interface reads 'data_addr_muxd' and 'data_addr_sel'); wait
-- for 'busy_out' = '0'.  The 'data_addr_muxd' and 'data_addr_sel' must remain
-- constant through this step.
--
-- Put the command's data on 'data_addr_muxd'; set 'data_addr_sel' to '1'.
--
-- Perform the same req/busy handshake as for the address part.
--
-- Read the response and error bit from 'resp_out' and 'resp_err_out'
-- respectively.
--
-- If the RPi wants to repeatedly issue the same command, but with different
-- data each time, it can keep 'data_addr_sel' set to '1' and handshake just
-- the data octet in each time.  (E.g., when writing a tape.)
--
-- When wrapped in a Syncd_RPi_Colossus instance, further signal-level
-- synchronisation is performed by a 'synchronizer' instance.

------------------------------------------------------------------------------

entity RPI_Interface is

  port (
    clk            : in  std_logic;
    -- RPI-facing side:
    data_addr_muxd : in  RPi_Data_Addr_Muxd_t;
    data_addr_sel  : in  std_logic;
    req            : in  std_logic;
    busy_out       : out std_logic := '0';
    resp_err_out   : out std_logic := '0';
    resp_out       : out RPi_Response_t := Ctrl_Response_ZERO;
    -- Colossus-facing side:
    ctrl_o         : out Ctrl_Bus_To_Target_t := CTRL_BUS_TO_TARGET_ZERO;
    ctrl_i         : in  Ctrl_Bus_Fr_Target_t := CTRL_BUS_FR_TARGET_ZERO);

end entity RPI_Interface;

architecture behaviour of RPI_Interface is

  type FSM_State_t is (Idle, Req_Rcvd, Sent_Tgt_Probe,
                       Examining_Tgt_Probe_Response, Tgt_Working);

  signal state : FSM_State_t := Idle;

begin

  state_machine : process (clk)
  is
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if req = '1' then
            busy_out <= '1';
            state    <= Req_Rcvd;
          end if;
        --
        when Req_Rcvd =>
          if req = '0' then
            if data_addr_sel = '0' then
              ctrl_o.addr  <= unsigned(data_addr_muxd);
              resp_err_out <= '0';
              resp_out     <= x"00";
              busy_out     <= '0';
              state        <= Idle;
            else
              ctrl_o.data  <= data_addr_muxd;
              ctrl_o.wr_en <= '1';
              state        <= Sent_Tgt_Probe;
            end if;
          end if;
        --
        when Sent_Tgt_Probe =>
          ctrl_o.wr_en <= '0';
          state        <= Examining_Tgt_Probe_Response;
        --
        when Examining_Tgt_Probe_Response =>
          if ctrl_i.busy = '0' then
            resp_err_out <= '1';
            resp_out     <= x"01";    -- No Target Found At Address
            busy_out     <= '0';
            state        <= Idle;
          else
            state <= Tgt_Working;
          end if;
        --
        when Tgt_Working =>
          if ctrl_i.busy = '0' then
            resp_err_out <= ctrl_i.err;
            resp_out     <= ctrl_i.resp;
            busy_out     <= '0';
            state        <= Idle;
          end if;
      end case;
    end if;
  end process state_machine;

end architecture behaviour;
