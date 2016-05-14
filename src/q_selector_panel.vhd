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

entity Q_Selector_Panel is

  generic (
    CONFIG_MAPPED_ADDR : integer;
    CONTROL_MAPPED_ADDR : integer);

  port (
    -- clock:
    clk          : in  std_logic;
    -- command interface:
    cmd_ctrl_i   : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o   : out Ctrl_Bus_Fr_Target_t;
    -- stream inputs and output:
    z_i          : in  TP_Letter_t;
    chi_i        : in  TP_Letter_t;
    psi_i        : in  TP_Letter_t;
    q_delta_o    : out std_logic;
    q_o          : out TP_Letter_t;
    -- automatic control:
    q_sel_ctrl_i : in  Q_Selector_Ctrl_t);

end entity Q_Selector_Panel;

architecture behaviour of Q_Selector_Panel is

  signal config_cmd_ctrl_o : Ctrl_Bus_Fr_Target_t;
  signal control_cmd_ctrl_o : Ctrl_Bus_Fr_Target_t := CTRL_BUS_FR_TARGET_ZERO;
  signal q_selector_cfg : Q_Selector_Cfg_t;
  signal manual_ctrl : Q_Selector_Ctrl_t := Q_SELECTOR_CTRL_ZERO;
  signal combined_ctrl : Q_Selector_Ctrl_t;

begin

  q_selector : entity work.Q_Selector
    port map (
      clk    => clk,
      ctrl_i => combined_ctrl,
      z_i    => z_i,
      chi_i  => chi_i,
      psi_i  => psi_i,
      cfg_i  => q_selector_cfg,
      q_delta_o => q_delta_o,
      q_o    => q_o);

  q_selector_config_register : entity work.Q_Selector_Config_Register
    generic map (
      MAPPED_ADDR => CONFIG_MAPPED_ADDR)
    port map (
      clk         => clk,
      ctrl_i      => cmd_ctrl_i,
      ctrl_o      => config_cmd_ctrl_o,
      q_sel_cfg_o => q_selector_cfg);

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Cmd_Done, Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      control_cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
      case state is
        when Idle =>
          manual_ctrl <= Q_SELECTOR_CTRL_ZERO;
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = CONTROL_MAPPED_ADDR then
              control_cmd_ctrl_o.busy <= '1';
              case cmd_ctrl_i.data is
                -- 0x00 Reset 'one back' registers
                -- 0x01 Calculate Q and update 'one back' (one-shot)
                when x"00" =>
                  manual_ctrl.rst <= '1';
                  cmd_success_code := x"b4";
                  state := Cmd_Done;
                when x"01" =>
                  manual_ctrl.en <= '1';
                  cmd_success_code := x"b5";
                  state := Cmd_Done;
                when others =>
                  state := Bad_Sub_Cmd;
              end case;
            end if;
          end if;
        when Cmd_Done =>
          manual_ctrl <= Q_SELECTOR_CTRL_ZERO;
          ctrl_cmd_success(control_cmd_ctrl_o, cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(control_cmd_ctrl_o, x"59");
          state := Idle;
      end case;
    end if;
  end process command_target;

  combined_ctrl <= q_sel_ctrl_i or manual_ctrl;
  cmd_ctrl_o <= config_cmd_ctrl_o or control_cmd_ctrl_o;

end architecture behaviour;
