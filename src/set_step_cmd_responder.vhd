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
library work;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.types.all;

------------------------------------------------------------------------------

entity Set_Step_Command_Responder is

  generic (
    BODY_ID : Cam_Wheel_Step_Count_t);

  port (
    clk                   : in  std_logic;
    step_set_cmd_i        : in  Cam_Wheel_Step_Count_t;
    step_counts_o         : out Cam_Wheel_Step_Count_t;
    step_counts_set_adv_o : out std_logic);

end entity Set_Step_Command_Responder;

architecture behaviour of Set_Step_Command_Responder is
begin

  control : process (clk)
  is
    type FSM_State_t is (Idle, Checking_Body_Id, Relaying_Set_Counts_Cmd);
    variable state : FSM_State_t := Idle;
    variable n_values : integer range 0 to N_WHEELS-1;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          step_counts_set_adv_o <= '0';
          step_counts_o <= CAM_WHEEL_STEP_COUNT_ZERO;
          if step_set_cmd_i = STEP_SET_CMD_PREAMBLE then
            state := Checking_Body_Id;
          end if;
        --
        when Checking_Body_Id =>
          if step_set_cmd_i = BODY_ID or step_set_cmd_i = BODY_ID_BROADCAST then
            step_counts_set_adv_o <= '1';
            n_values := N_WHEELS - 1;
            state := Relaying_Set_Counts_Cmd;
          else
            state := Idle;
          end if;
        --
        when Relaying_Set_Counts_Cmd =>
          step_counts_set_adv_o <= '0';
          step_counts_o <= step_set_cmd_i;
          if n_values = 0 then
            state := Idle;
          else
            n_values := n_values - 1;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
