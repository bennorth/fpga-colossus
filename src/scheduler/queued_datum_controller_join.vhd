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

------------------------------------------------------------------------

entity Queued_Datum_Controller_Join is
  port (
    clk         : in  std_logic;
    --
    left_1_rdy_i  : in  std_logic;
    left_1_bsy_o  : out std_logic;
    left_2_rdy_i  : in  std_logic;
    left_2_bsy_o  : out std_logic;
    right_rdy_o : out std_logic;
    right_bsy_i : in  std_logic);
end entity Queued_Datum_Controller_Join;


architecture behaviour of Queued_Datum_Controller_Join is
begin

  control : process (clk) is
    type FSM_State_t is (Awaiting_Input_1_Ready,
                         Awaiting_Input_1_Acquisition_Acknowledge,
                         Awaiting_Input_2_Ready,
                         Awaiting_Input_2_Acquisition_Acknowledge,
                         Awaiting_Output_Acquisition,
                         Awaiting_Output_Release);
    variable state : FSM_State_t := Awaiting_Input_1_Ready;
  begin
    if rising_edge(clk) then
      case state is
        when Awaiting_Input_1_Ready =>
          left_2_bsy_o <= '0';
          right_rdy_o <= '0';
          if left_1_rdy_i = '1' then
            left_1_bsy_o <= '1';
            state := Awaiting_Input_1_Acquisition_Acknowledge;
          else
            left_1_bsy_o <= '0';
          end if;
        when Awaiting_Input_1_Acquisition_Acknowledge =>
          if left_1_rdy_i = '0' then
            state := Awaiting_Input_2_Ready;
          end if;
        when Awaiting_Input_2_Ready =>
          if left_2_rdy_i = '1' then
            left_2_bsy_o <= '1';
            state := Awaiting_Input_2_Acquisition_Acknowledge;
          end if;
        when Awaiting_Input_2_Acquisition_Acknowledge =>
          if left_2_rdy_i = '0' then
            right_rdy_o <= '1';
            state := Awaiting_Output_Acquisition;
          end if;
        when Awaiting_Output_Acquisition =>
          if right_bsy_i = '1' then
            right_rdy_o <= '0';
            state := Awaiting_Output_Release;
          end if;
        when Awaiting_Output_Release =>
          if right_bsy_i = '0' then
            left_1_bsy_o <= '0';
            left_2_bsy_o <= '0';
            state := Awaiting_Input_1_Ready;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
