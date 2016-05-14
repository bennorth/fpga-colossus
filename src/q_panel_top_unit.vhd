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
use work.types.all;

------------------------------------------------------------------------------

entity Q_Panel_Top_Unit is

  port (
    clk            : in  std_logic;
    -- configuration:
    cfg            : in  Q_Panel_Top_Unit_Cfg_t;
    -- input stream:
    q              : in  TP_Letter_t;
    -- outputs:
    summand_factor : out Counter_1b_Vec_t);

end Q_Panel_Top_Unit;

architecture behaviour of Q_Panel_Top_Unit is
begin

  compute_summand_factor : process (clk)
  is
    variable letter_match  : std_logic;
    variable impulse_match : std_logic;
  begin
    if rising_edge(clk) then
      letter_match := '1';
      for i in q'range loop
        impulse_match := (not cfg.match_en(i))
                         or (Q(i) xnor cfg.match_tgt(i));
        letter_match  := letter_match and impulse_match;
      end loop;

      letter_match := letter_match xor cfg.negate;

      for i in summand_factor'range loop
        summand_factor(i) <= (not cfg.counter_en(i)) or letter_match;
      end loop;
    end if;
  end process;

end behaviour;
