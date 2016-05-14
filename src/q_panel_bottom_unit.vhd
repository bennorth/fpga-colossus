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

entity Q_Panel_Bottom_Unit is

  port (
    clk            : in  std_logic;
    -- configuration:
    cfg            : in  Q_Panel_Bottom_Unit_Cfg_t;
    -- input stream:
    q              : in  TP_Letter_t;
    -- outputs:
    summand_factor : out Counter_1b_Vec_t);

end Q_Panel_Bottom_Unit;

architecture behaviour of Q_Panel_Bottom_Unit is
begin

  compute_summand_factor : process (clk)
  is
    variable impulse_sum_prod  : std_logic;
    variable matches_target  : std_logic;
  begin
    if rising_edge(clk) then
      impulse_sum_prod := '0';
      for i in q'range loop
        impulse_sum_prod := (impulse_sum_prod
                             xor (cfg.coeff(i) and q(i)));
      end loop;

      matches_target := impulse_sum_prod xnor cfg.tgt;

      for i in summand_factor'range loop
        summand_factor(i) <= (not cfg.counter_en(i)) or matches_target;
      end loop;
    end if;
  end process;

end behaviour;
