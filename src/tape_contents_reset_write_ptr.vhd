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

entity Tape_Contents_Controller_Reset_Write_Ptr is

  generic (
    MAPPED_ADDR : Ctrl_Addr_t);

  port (
    clk         : in  std_logic;
    --
    ctrl_i      : in  Ctrl_Bus_To_Target_t;
    ctrl_o      : out Ctrl_Bus_Fr_Target_t;
    ram_ctrl_o  : out Ctrl_Bus_To_RAM_t;
    --
    rst_write_n : out std_logic);

end entity Tape_Contents_Controller_Reset_Write_Ptr;

architecture behaviour of Tape_Contents_Controller_Reset_Write_Ptr is
begin

  write_tape_0_cmd : process (clk)
  is
    type FSM_State_t is (Idle, Write_Ptr_Reset, Bad_Write_0_Data);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if ctrl_i.wr_en = '1' then
            if ctrl_i.addr = MAPPED_ADDR then
              ctrl_o.busy      <= '1';
              case ctrl_i.data is
                when x"00" =>
                  rst_write_n <= '1';
                  state       := Write_Ptr_Reset;
                when others =>
                  state := Bad_Write_0_Data;
              end case;
            end if;
          else
            ctrl_o     <= CTRL_BUS_FR_TARGET_ZERO;
            ram_ctrl_o <= CTRL_BUS_TO_RAM_ZERO;
          end if;
        when Write_Ptr_Reset =>
          ram_ctrl_o.wr_en <= '0';
          ctrl_cmd_success(ctrl_o, Tape_Loop_Write_0_OK);
          rst_write_n      <= '0';
          state            := Idle;
        when Bad_Write_0_Data =>
          ctrl_cmd_failure(ctrl_o, x"34");
          state       := Idle;
      end case;
    end if;
  end process write_tape_0_cmd;

end architecture behaviour;

