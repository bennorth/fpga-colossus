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
use work.utils.all;

------------------------------------------------------------------------------

-- The non-selector part of the Q panel [53J(b)--(e)], excluding 'remembering'
-- aka 'multiple testing' controls [53J(h)], and also excluding the 'total
-- motor' conditions [53J(i)].
--
-- The 'top rows' [53J(c),(d)] are instances of Q_Panel_Top_Unit, configured as
-- follows.  A 'top row' of the real Colossus has a group of five three-position
-- switches on the left to (perhaps) impose conditions on individual impulses.
-- We implement this as a group of 'enable' bits and a group of 'target' bits.
-- If an 'enable' bit is '0', then the 'target' bit is ignored, and no condition
-- is imposed on that impulse --- this corresponds to the neutral (centre)
-- position of the real switch.  If the 'enable' bit is '1', then the condition
-- imposed is that the impulse must match the 'target' bit.  So a bit with
-- "en='1', tgt='0'" corresponds to the real switch being 'thrown to dot', and
-- "en='1', tgt='1'" to 'thrown to cross'.  The 'negate' switch is mapped to the
-- 'negate' signal of the row's config.  The group of five 'counter' switches at
-- the right of the real row are mapped to the five bits of 'counter_en' here.
-- Sub-optimally, 'Counter 0' corresponds to the most-significant of the five
-- used bits of the config register --- I could claim I was following the
-- approach described at the end of 53E: "It will be noticed that the labelling
-- is inconsistent".
--
-- The 'bottom rows' [53J(e)] are instances of Q_Panel_Bottom_Unit.  The real
-- impulse selector switches 'can be thrown down only', to include that impulse
-- in the sum on which a condition will be imposed.  Equivalently, we implement
-- a 'coeff' of 0 or 1 for each impulse.  The real Colossus imposes the
-- condition by means of a two-position switch, to say whether the sum of the
-- chosen impulses must be dot or cross.  This is our 'tgt'.  The counter-choice
-- switches are 'counter_en', as for the top rows.
--
-- There are two sets of negate switches.  The set of ten 'top rows' has a set
-- of five 'not' switches, one per counter [53J(d), third-from-last sentence].
-- There is also a set of five global 'not' switches [53J(e), last sentence].
-- These are gathered here into the Q_Panel_Negates_Config_Register.

------------------------------------------------------------------------------

entity Q_Panel is

  generic (
    BASE_ADDR : integer);

  port (
    -- clock:
    clk           : in  std_logic;
    -- command interface:
    ctrl_i : in  Ctrl_Bus_To_Target_t;
    ctrl_o : out Ctrl_Bus_Fr_Target_t;
    -- input stream:
    q             : in  TP_Letter_t;
    -- outputs:
    summands      : out Counter_1b_Vec_t);

end Q_Panel;

architecture behaviour of Q_Panel is

  -- no '-1' at end of range calculation because we need an extra slot
  -- for the target which is the 'negates' config register.
  signal subtgt_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t
                         (0 to N_Q_PANEL_TOP_UNITS+N_Q_PANEL_BOTTOM_UNITS);

  signal top_unit_summand_factors : Counter_1b_Vec_Vec_t
                                    (0 to N_Q_PANEL_TOP_UNITS-1);

  signal top_unit_cfgs : Q_Panel_Top_Unit_Cfg_Vec_t
                         (0 to N_Q_PANEL_TOP_UNITS-1);

  signal bottom_unit_cfgs : Q_Panel_Bottom_Unit_Cfg_Vec_t
                            (0 to N_Q_PANEL_BOTTOM_UNITS-1);

  signal bottom_unit_summand_factors : Counter_1b_Vec_Vec_t
                                       (0 to N_Q_PANEL_BOTTOM_UNITS-1);

  signal whole_panel_cfg : Q_Panel_Cfg_t;

begin

  top_unit : for j in 0 to (N_Q_PANEL_TOP_UNITS - 1) generate
  begin
    top_unit : entity work.Q_Panel_Top_Unit
    port map (
      clk            => clk,
      cfg            => top_unit_cfgs(j),
      q              => q,
      summand_factor => top_unit_summand_factors(j));

    top_unit_cfg_reg : entity work.Q_Panel_Top_Unit_Config_Register
    generic map (
      MAPPED_ADDR => BASE_ADDR + (3 * j))
    port map (
      clk    => clk,
      ctrl_i => ctrl_i,
      ctrl_o => subtgt_ctrl_o(j),
      cfg_o  => top_unit_cfgs(j));
  end generate;

  bottom_unit : for j in 0 to (N_Q_PANEL_BOTTOM_UNITS - 1) generate
  begin
    bottom_unit : entity work.Q_Panel_Bottom_Unit
    port map (
      clk            => clk,
      cfg            => bottom_unit_cfgs(j),
      q              => q,
      summand_factor => bottom_unit_summand_factors(j));

    bottom_unit_cfg_reg : entity work.Q_Panel_Bottom_Unit_Config_Register
    generic map (
      MAPPED_ADDR => BASE_ADDR + 30 + (2 * j))
    port map (
      clk    => clk,
      ctrl_i => ctrl_i,
      ctrl_o => subtgt_ctrl_o(10 + j),
      cfg_o  => bottom_unit_cfgs(j));
  end generate;

  negates_cfg_reg : entity work.Q_Panel_Negates_Config_Register
    generic map (
      MAPPED_ADDR => BASE_ADDR + 40)
    port map (
      clk    => clk,
      ctrl_i => ctrl_i,
      ctrl_o => subtgt_ctrl_o(15),
      cfg_o  => whole_panel_cfg);

  compute_summands : process(clk)
  is
    variable summand_tmp : Counter_1b_Vec_t;
  begin
    if rising_edge(clk) then
      summand_tmp := (others => '1');
      for j in N_Q_PANEL_TOP_UNITS-1 downto 0 loop
        summand_tmp := summand_tmp and top_unit_summand_factors(j);
      end loop;

      summand_tmp := summand_tmp xor whole_panel_cfg.top_negates;

      for j in N_Q_PANEL_BOTTOM_UNITS-1 downto 0 loop
        summand_tmp := summand_tmp and bottom_unit_summand_factors(j);
      end loop;

      summands <= (summand_tmp
                   xor whole_panel_cfg.global_negates);
    end if;
  end process;

  reduce_ctrl_out : process(subtgt_ctrl_o)
  is
    variable v_bus : Ctrl_Bus_Fr_Target_t;
  begin
    v_bus := CTRL_BUS_FR_TARGET_ZERO;

    for i in subtgt_ctrl_o'range loop
      v_bus := v_bus or subtgt_ctrl_o(i);
    end loop;

    ctrl_o <= v_bus;
  end process;

end architecture;
