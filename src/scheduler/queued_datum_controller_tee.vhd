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

entity Queued_Datum_Controller_Tee is
  port (
    clk           : in  std_logic;
    --
    left_rdy_i    : in  std_logic;
    left_bsy_o    : out std_logic;
    right_1_rdy_o : out std_logic;
    right_1_bsy_i : in  std_logic;
    right_2_rdy_o : out std_logic;
    right_2_bsy_i : in  std_logic);
end entity Queued_Datum_Controller_Tee;


architecture behaviour of Queued_Datum_Controller_Tee is
begin

  control : process (clk) is
    type FSM_State_t is (Awaiting_Input_Ready,
                         Awaiting_Input_Acquisition_Acknowledge,
                         Awaiting_Output_1_Acquisition,
                         Awaiting_Output_1_Release,
                         Awaiting_Output_2_Acquisition,
                         Awaiting_Output_2_Release);
    variable state : FSM_State_t := Awaiting_Input_Ready;
  begin
    if rising_edge(clk) then
      case state is
        when Awaiting_Input_Ready =>
          right_1_rdy_o <= '0';
          right_2_rdy_o <= '0';
          if left_rdy_i = '1' then
            left_bsy_o <= '1';
            state := Awaiting_Input_Acquisition_Acknowledge;
          else
            left_bsy_o <= '0';
          end if;
        when Awaiting_Input_Acquisition_Acknowledge =>
          if left_rdy_i = '0' then
            right_1_rdy_o <= '1';
            right_2_rdy_o <= '1';
            state := Awaiting_Output_1_Acquisition;
          end if;
        when Awaiting_Output_1_Acquisition =>
          if right_1_bsy_i = '1' then
            right_1_rdy_o <= '0';
            state := Awaiting_Output_2_Acquisition;
          end if;
        when Awaiting_Output_2_Acquisition =>
          if right_2_bsy_i = '1' then
            right_2_rdy_o <= '0';
            state := Awaiting_Output_1_Release;
          end if;
        when Awaiting_Output_1_Release =>
          if right_1_bsy_i = '0' then
            state := Awaiting_Output_2_Release;
          end if;
        when Awaiting_Output_2_Release =>
          if right_2_bsy_i = '0' then
            left_bsy_o <= '0';
            state := Awaiting_Input_Ready;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
