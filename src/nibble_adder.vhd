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

-------------------------------------------------------------------------------

-- Was used for testing purposes when first moving the design to actual FPGA
-- connected to actual RPi.  Very simple self-contained command target.

-------------------------------------------------------------------------------

entity Nibble_Adder_Panel is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk        : in  std_logic;
    cmd_ctrl_i : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o : out Ctrl_Bus_Fr_Target_t);

end entity Nibble_Adder_Panel;

architecture behaviour of Nibble_Adder_Panel is

begin

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Cmd_Done);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
    variable n0, n1 : unsigned(3 downto 0) := x"0";
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              n0 := unsigned(cmd_ctrl_i.data(3 downto 0));
              n1 := unsigned(cmd_ctrl_i.data(7 downto 4));
              cmd_success_code := x"0" & std_logic_vector(n0 + n1);
              state := Cmd_Done;
            end if;
          else
            cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Cmd_Done =>
          ctrl_cmd_success(cmd_ctrl_o, cmd_success_code);
          state := Idle;
      end case;
    end if;
  end process command_target;

end architecture behaviour;
