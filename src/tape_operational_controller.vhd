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
use work.utils.all;

------------------------------------------------------------------------------

entity Tape_Operational_Controller is

  port (
    clk           : in  std_logic;
    --
    ctrl_i        : in  Ctrl_Bus_To_Bedstead_t;
    aug_z         : out Aug_TP_Letter_t;
    --
    ram_ctrl_o    : out Ctrl_Bus_To_RAM_t;
    data_from_ram : in  Tape_Loop_RAM_Data_t);

end entity Tape_Operational_Controller;

architecture behaviour of Tape_Operational_Controller is
begin

  control : process (clk)
  is
    variable read_addr : Tape_Loop_RAM_Addr_t := ram_addr_f_int(0);
  begin
    if rising_edge(clk) then
      if ctrl_i.mv_rst = '1' then
        read_addr := ram_addr_f_int(0);
      elsif ctrl_i.mv_en = '1' then
        read_addr := read_addr + 1;
      end if;

      ram_ctrl_o.req <= '1';
      ram_ctrl_o.addr <= read_addr;
      ram_ctrl_o.data <= (others => '0');
      ram_ctrl_o.wr_en <= '0';

      aug_z.letter <= data_from_ram(4 downto 0);
      aug_z.stop   <= data_from_ram(5);
    end if;
  end process control;

end architecture behaviour;
