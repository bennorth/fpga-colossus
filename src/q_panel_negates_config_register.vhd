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
use work.types.all;

-------------------------------------------------------------------------------

entity Q_Panel_Negates_Config_Register is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk    : in  std_logic;
    --
    ctrl_i : in  Ctrl_Bus_To_Target_t;
    ctrl_o : out Ctrl_Bus_Fr_Target_t;
    --
    cfg_o  : out Q_Panel_Cfg_t);

end entity Q_Panel_Negates_Config_Register;

architecture behaviour of Q_Panel_Negates_Config_Register is

  signal raw_cfg : std_logic_vector(15 downto 0);

begin

  cfg_reg : entity work.Generic_Config_Register
    generic map (BASE_ADDR => MAPPED_ADDR, N_OCTETS => 2)
    port map (clk => clk,
              ctrl_i => ctrl_i, ctrl_o => ctrl_o,
              cfg_o => raw_cfg);

  cfg_o.top_negates <= raw_cfg(4 downto 0);
  cfg_o.global_negates <= raw_cfg(12 downto 8);

end architecture behaviour;
