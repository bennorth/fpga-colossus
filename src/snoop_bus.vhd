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

entity Snoop_Bus is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk      : in  std_logic;
    --
    ctrl_i   : in  Ctrl_Bus_To_Target_t;
    ctrl_o   : out Ctrl_Bus_Fr_Target_t;
    --
    aug_z    : in  Aug_TP_Letter_t;
    chi      : in  TP_Letter_t;
    q        : in  TP_Letter_t;
    summands : in  Counter_1b_Vec_t);

end entity Snoop_Bus;

architecture behaviour of Snoop_Bus is
begin

  snoop : process (clk)
  is
    type FSM_State_t is (Idle, Do_Snoop);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if ctrl_i.wr_en = '1' then
            if ctrl_i.addr = MAPPED_ADDR then
              ctrl_o.busy <= '1';
              state := Do_Snoop;
            end if;
          else
            ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Do_Snoop =>
          case ctrl_i.data is
            when x"00" =>
              ctrl_cmd_success(ctrl_o, aug_z.stop & "00" & aug_z.letter);
            when x"01" =>
              ctrl_cmd_success(ctrl_o, "000" & q);
            when x"02" =>
              ctrl_cmd_success(ctrl_o, "000" & chi);
            when x"05" =>
              ctrl_cmd_success(ctrl_o, "000" & summands);
            when others =>
              ctrl_cmd_failure(ctrl_o, x"34");
          end case;
          state := Idle;
      end case;
    end if;
  end process snoop;

end architecture behaviour;
