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

entity Tape_Contents_Controller_Clear_Tape is

  generic (
    MAPPED_ADDR : Ctrl_Addr_t);

  port (
    clk        : in  std_logic;
    --
    ctrl_i     : in  Ctrl_Bus_To_Target_t;
    ctrl_o     : out Ctrl_Bus_Fr_Target_t;
    ram_ctrl_o : out Ctrl_Bus_To_RAM_t);

end entity Tape_Contents_Controller_Clear_Tape;

architecture behaviour of Tape_Contents_Controller_Clear_Tape is
begin

  clear_tape_cmd : process (clk)
  is
    type FSM_State_t is (Idle, Clear_0, Clear_Remainder);
    variable state      : FSM_State_t := Idle;
    variable clear_addr : Tape_Loop_RAM_Addr_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if ctrl_i.wr_en = '1' then
            if ctrl_i.addr = MAPPED_ADDR then
              ctrl_o.busy <= '1';
              state       := Clear_0;
            end if;
          else
            ctrl_o     <= CTRL_BUS_FR_TARGET_ZERO;
            ram_ctrl_o <= CTRL_BUS_TO_RAM_ZERO;
          end if;
        when Clear_0 =>
          ram_ctrl_o.req   <= '1';
          ram_ctrl_o.addr  <= (others => '0');
          ram_ctrl_o.data  <= Tape_Loop_RAM_NO_LETTER;
          ram_ctrl_o.wr_en <= '1';
          clear_addr       := ram_addr_f_int(1);
          state            := Clear_Remainder;
        when Clear_Remainder =>
          if clear_addr = 0 then
            ram_ctrl_o.wr_en <= '0';
            ctrl_cmd_success(ctrl_o, Tape_Loop_Clear_OK);
            state            := Idle;
          else
            ram_ctrl_o.addr <= clear_addr;
            clear_addr      := clear_addr + 1;
          end if;
      end case;
    end if;
  end process clear_tape_cmd;

end architecture behaviour;
