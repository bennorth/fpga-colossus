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

-- Protocol is driven by various signals within 'ctrl_i', working with a 'live'
-- internal counter, and an 'output' / 'latched' value:
--
-- count_rst: reset the internal 'live' count, leaving the 'output' count alone
--
-- count_en: iff the 'summand' input is '1', increment the 'live' count (once
-- per cycle that 'count_en' remains asserted and the 'summand' remains '1')
--
-- output_en: transfer the 'live' count to the 'output'/'latched' value,
-- leaving the 'live' count alone
--
-- The collection of internal 'count' signals across all counters implements the
-- per-body 'live counters' data-slot; the collection of 'count_o' outputs
-- across all counters implements the per-body 'latched counters' data-slot.

------------------------------------------------------------------------------

entity Counter is

  generic (
    WIDTH : integer);

  port (
    clk     : in  std_logic;
    summand : in  std_logic;
    ctrl_i  : in  Counter_Ctrl_t;
    count_o : out unsigned(WIDTH-1 downto 0));

end Counter;

architecture behaviour of Counter is

    signal count : unsigned(WIDTH-1 downto 0) := (others => '0');

begin

  counter : process (clk)
  is
  begin
    if rising_edge(clk) then
      if ctrl_i.count_rst = '1' then
        count <= (others => '0');
      elsif ctrl_i.count_en = '1' then
        if summand = '1' then
          count <= count + 1;
        end if;
      elsif ctrl_i.output_en = '1' then
        count_o <= count;
      end if;
    end if;
  end process counter;

end architecture behaviour;
