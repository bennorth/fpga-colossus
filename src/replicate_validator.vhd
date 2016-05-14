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
use work.utils.all;

------------------------------------------------------------------------------

entity Replicate_Validator is

  port (
    clk : in std_logic;
    --
    to_tgt_i : in Ctrl_Bus_To_Target_t;
    from_tgt_o : out Ctrl_Bus_Fr_Target_t := CTRL_BUS_FR_TARGET_ZERO;
    --
    to_this_tgt_o : out Ctrl_Bus_To_Target_t := CTRL_BUS_TO_TARGET_ZERO;
    from_this_tgt_i : in Ctrl_Bus_Fr_Target_t;
    --
    to_next_tgt_o : out Ctrl_Bus_To_Target_t := CTRL_BUS_TO_TARGET_ZERO;
    from_next_tgt_i : in Ctrl_Bus_Fr_Target_t);

end entity Replicate_Validator;

architecture behaviour of Replicate_Validator is

  signal from_this_tgt : Ctrl_Bus_Fr_Target_t;
  signal from_next_tgt : Ctrl_Bus_Fr_Target_t;

begin

  this_response_latch : entity work.Response_Latch
    port map (
      clk            => clk,
      tgt_response_i => from_this_tgt_i,
      tgt_response_o => from_this_tgt);

  next_response_latch : entity work.Response_Latch
    port map (
      clk            => clk,
      tgt_response_i => from_next_tgt_i,
      tgt_response_o => from_next_tgt);

  control : process (clk)
  is
    type FSM_State_t is (Idle,
                         Ending_Wr_En_Pulses,
                         Latency_Through_Latches,
                         Validating_Work_Started,
                         Awaiting_Work_Done,
                         Comparing_Responses);
    variable state : FSM_State_t := Idle;

    variable error_response : RPi_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if to_tgt_i.wr_en = '1' then
            from_tgt_o.busy <= '1';
            to_this_tgt_o <= to_tgt_i;
            to_next_tgt_o <= to_tgt_i;
            state := Ending_Wr_En_Pulses;
          end if;
        --
        when Ending_Wr_En_Pulses =>
          to_this_tgt_o.wr_en <= '0';
          to_next_tgt_o.wr_en <= '0';
          state := Latency_Through_Latches;
          error_response := x"00";
        --
        when Latency_Through_Latches =>
          state := Validating_Work_Started;
        --
        when Validating_Work_Started =>
          if from_this_tgt.busy = '0' then
            error_response(1) := '1';
          end if;
          if from_next_tgt.busy = '0' then
            error_response(2) := '1';
          end if;
          if error_response(2 downto 1) /= "00" then
            ctrl_cmd_failure(from_tgt_o, error_response);
            state := Idle;
          else
            state := Awaiting_Work_Done;
          end if;
        --
        when Awaiting_Work_Done =>
          if (from_this_tgt.busy = '0' and from_next_tgt.busy = '0') then
            state := Comparing_Responses;
          end if;
        --
        when Comparing_Responses =>
          if (from_this_tgt.err /= from_next_tgt.err
              or from_this_tgt.resp /= from_next_tgt.resp) then
            ctrl_cmd_failure(from_tgt_o, x"07");
          else
            if from_this_tgt.err = '1' then
              ctrl_cmd_failure(from_tgt_o, from_this_tgt.resp);
            else
              ctrl_cmd_success(from_tgt_o, from_this_tgt.resp);
            end if;
          end if;
          state := Idle;
      end case;
    end if;
  end process control;

end architecture behaviour;
