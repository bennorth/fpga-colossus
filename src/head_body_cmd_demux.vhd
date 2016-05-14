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

entity Head_Body_Cmd_Demux is

  port (
    clk         : in  std_logic;
    --
    cmd_i       : in  Ctrl_Bus_To_Target_t;
    resp_o      : out Ctrl_Bus_Fr_Target_t := CTRL_BUS_FR_TARGET_ZERO;
    --
    head_tail_cmd_o  : out Ctrl_Bus_To_Target_t := CTRL_BUS_TO_TARGET_ZERO;
    head_tail_resp_i : in  Ctrl_Bus_Fr_Target_t;
    --
    body_cmd_o  : out Ctrl_Bus_To_Target_t := CTRL_BUS_TO_TARGET_ZERO;
    body_resp_i : in  Ctrl_Bus_Fr_Target_t);

end entity Head_Body_Cmd_Demux;

architecture behaviour of Head_Body_Cmd_Demux is
begin

  control : process (clk)
  is
    type FSM_State_t is (Idle,
                         Ending_Head_Tail_Wr_En_Pulse,
                         Validating_Head_Tail_Work_Started,
                         Awaiting_Head_Tail_Work_Done,
                         Ending_Body_Wr_En_Pulse,
                         Validating_Body_Work_Started,
                         Awaiting_Body_Work_Done);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_i.wr_en = '1' then
            resp_o.busy <= '1';
            if cmd_i.addr(7 downto 5) = "111" then
              head_tail_cmd_o <= cmd_i;
              state := Ending_Head_Tail_Wr_En_Pulse;
            else
              body_cmd_o <= cmd_i;
              state := Ending_Body_Wr_En_Pulse;
            end if;
          else
            resp_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        --
        when Ending_Head_Tail_Wr_En_Pulse =>
          head_tail_cmd_o.wr_en <= '0';
          state := Validating_Head_Tail_Work_Started;
        --
        when Validating_Head_Tail_Work_Started =>
          if head_tail_resp_i.busy = '1' then
            state := Awaiting_Head_Tail_Work_Done;
          else
            ctrl_cmd_failure(resp_o, x"09");
            state := Idle;
          end if;
        --
        when Awaiting_Head_Tail_Work_Done =>
          if head_tail_resp_i.busy = '0' then
            resp_o <= head_tail_resp_i;
            state := Idle;
          end if;
        --
        when Ending_Body_Wr_En_Pulse =>
          body_cmd_o.wr_en <= '0';
          state := Validating_Body_Work_Started;
        --
        when Validating_Body_Work_Started =>
          if body_resp_i.busy = '1' then
            state := Awaiting_Body_Work_Done;
          else
            ctrl_cmd_failure(resp_o, x"0a");
            state := Idle;
          end if;
        --
        when Awaiting_Body_Work_Done =>
          if body_resp_i.busy = '0' then
            resp_o <= body_resp_i;
            state := Idle;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
