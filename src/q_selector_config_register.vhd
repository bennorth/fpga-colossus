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

-- The real Colossus was configured via a three-way switch for each of the three
-- potential contributors (Z, Chi, Psi) to Q [53J(a) of GRT].  Each switch has a
-- neutral position, and two active positions: X and delta-X.  We represent this
-- as two bits, being 'enable' and 'delta'.  Under "enable = '0'", the state of
-- 'delta' is irrelevant.
--
-- We do not implement the per-impulse selector which is mentioned at the end
-- of 53J(a).

-------------------------------------------------------------------------------

entity Q_Selector_Config_Register is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk         : in  std_logic;
    --
    ctrl_i      : in  Ctrl_Bus_To_Target_t;
    ctrl_o      : out Ctrl_Bus_Fr_Target_t;
    --
    q_sel_cfg_o : out Q_Selector_Cfg_t);

end entity Q_Selector_Config_Register;

architecture behaviour of Q_Selector_Config_Register is

  signal raw_cfg : std_logic_vector(7 downto 0);

begin

  cfg_reg : entity work.Generic_Config_Register
    generic map (BASE_ADDR => MAPPED_ADDR, N_OCTETS => 1)
    port map (clk => clk,
              ctrl_i => ctrl_i, ctrl_o => ctrl_o,
              cfg_o => raw_cfg);

  q_sel_cfg_o.z_en <= raw_cfg(5);
  q_sel_cfg_o.z_delta <= raw_cfg(4);
  q_sel_cfg_o.chi_en <= raw_cfg(3);
  q_sel_cfg_o.chi_delta <= raw_cfg(2);
  q_sel_cfg_o.psi_en <= raw_cfg(1);
  q_sel_cfg_o.psi_delta <= raw_cfg(0);

end architecture behaviour;
