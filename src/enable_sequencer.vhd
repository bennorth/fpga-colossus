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

------------------------------------------------------------------------------

entity Enable_Sequencer is

  generic (
    N_OUTPUTS : integer);

  port (
    clk      : in  std_logic;
    en_adv_i : in  std_logic;
    en_o     : out std_logic_vector(0 to N_OUTPUTS-1));

end entity Enable_Sequencer;

architecture behaviour of Enable_Sequencer is
begin

  control : process (clk)
  is
    type FSM_State_t is (Idle, Sequencing);
    variable state : FSM_State_t := Idle;
    variable disable_idx : integer range 0 to N_OUTPUTS-1;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if en_adv_i = '1' then
            disable_idx := 0;
            en_o(0) <= '1';
            state := Sequencing;
          end if;
        when Sequencing =>
          en_o(disable_idx) <= '0';
          if disable_idx = N_OUTPUTS-1 then
            state := Idle;
          else
            disable_idx := disable_idx + 1;
            en_o(disable_idx) <= '1';
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
