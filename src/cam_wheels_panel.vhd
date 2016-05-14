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

-- To handle requests to set the step-counts, a Cam_Wheels_Panel receives
-- 'step_counts_i' and 'step_counts_set_adv_i'.  The input protocol is that
-- 'step_counts_set_adv_i' should be asserted one cycle before the first wheel's
-- desired step-count is presented on 'step_counts_i'.  The second wheel's
-- desired step-count should then be presented on 'step_counts_i' on the
-- following cycle, and so on.  The enabling of each wheel's 'set step count'
-- behaviour is handled by the Enable_Sequencer instance.  When all wheels have
-- set their step-counts, the Cam_Wheels_Panel asserts 'step_counts_set_done_o'.
-- Note that checking for the command-bus preamble and the target body-id is the
-- job of a Set_Step_Command_Responder instance, which is what drives our
-- 'step_counts_i' and 'step_counts_set_adv_i' inputs.
--
-- To handle requests to reset all wheels' movement, we just assert the
-- 'move_rst' of each cam-wheel.  There is some slight hoop-jumping to correctly
-- implement the 'req'/'done' protocol, but the reset operation takes a known
-- number of cycles so this can be handled here.
--
-- We provide a memory-like interface to the individual cam-wheels' step counts
-- via 'step_count_sel_i' and 'step_count_val_o'.

------------------------------------------------------------------------------

entity Cam_Wheels_Panel is

  -- Occupies 25 addresses: 2 addresses per wheel and then one for panel
  -- itself:
  --
  --  +0,  +2,  +4,  +6,  +8 --- CHI_1 up to CHI_5
  -- +10, +12, +14, +16, +18 --- PSI_1 up to PSI_5
  -- +20, +22                --- MU_0, MU_1
  -- +24                     --- panel-level commands

  generic (
    BASE_ADDR : integer);

  port (
    clk                    : in  std_logic;
    --
    move_en_i              : in  std_logic;
    move_reset_req_i       : in  std_logic;
    move_reset_done_o      : out std_logic;
    --
    step_counts_i          : in  Cam_Wheel_Step_Count_t;
    step_counts_set_adv_i  : in  std_logic;
    step_counts_set_done_o : out std_logic;
    --
    step_count_sel_i       : in  Cam_Wheel_Addr_t;
    step_count_val_o       : out Cam_Wheel_Step_Count_t;
    --
    chi_o                  : out TP_Letter_t;
    psi_o                  : out TP_Letter_t;
    mu_o                   : out Motor_Wheels_t;
    --
    cmd_ctrl_i             : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o             : out Ctrl_Bus_Fr_Target_t);

end entity Cam_Wheels_Panel;

architecture behaviour of Cam_Wheels_Panel is

  signal chi : TP_Letter_t;
  signal psi : TP_Letter_t;
  signal mu : Motor_Wheels_t;

  signal chi_ctrl : Cam_Wheel_Ctrl_Vec_t(0 to 4);
  signal psi_ctrl : Cam_Wheel_Ctrl_Vec_t(0 to 4);
  signal mu_ctrl : Cam_Wheel_Ctrl_Vec_t(0 to 1);

  signal step_count : Cam_Wheel_Step_Count_Vec_t(0 to N_WHEELS-1);
  signal step_count_set_req : std_logic_vector(0 to N_WHEELS-1);
  signal step_count_set_done : std_logic_vector(0 to N_WHEELS-1);

  signal manual_move_en : std_logic := '0';
  signal move_en : std_logic;
  signal auto_move_rst : std_logic;
  signal manual_move_rst : std_logic := '0';
  signal move_rst : std_logic;

  -- Number of command targets is:
  --
  -- N_WHEELS for the wheels themselves (each responding to two addresses, one
  -- for pattern loading and one for individual manual control)
  --
  -- 1 for panel-level commands
  --
  -- Hence we want N_WHEELS+1 sub-targets.
  --
  signal subtgt_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t(0 to N_WHEELS);

begin

  chi_unit : for i in 0 to 4 generate
  begin
    chi_unit : entity work.Cam_Wheel_Unit
      generic map (N_CAMS => N_CAMS_CHI(i+1), BASE_ADDR => BASE_ADDR + 2*i)
      port map (clk => clk, ctrl_i => chi_ctrl(i),
                step_count_o => step_count(i),
                step_count_set_o => step_count_set_done(i),
                w_o => chi(i+1),
                cmd_ctrl_i => cmd_ctrl_i, cmd_ctrl_o => subtgt_ctrl_o(i));
  end generate;

  psi_unit : for i in 0 to 4 generate
  begin
    psi_unit : entity work.Cam_Wheel_Unit
      generic map (N_CAMS => N_CAMS_PSI(i+1), BASE_ADDR => BASE_ADDR + 10 + 2*i)
      port map (clk => clk, ctrl_i => psi_ctrl(i),
                step_count_o => step_count(5 + i),
                step_count_set_o => step_count_set_done(5 + i),
                w_o => psi(i+1),
                cmd_ctrl_i => cmd_ctrl_i, cmd_ctrl_o => subtgt_ctrl_o(5 + i));
  end generate;

  mu_unit : for i in 0 to 1 generate
  begin
    mu_unit : entity work.Cam_Wheel_Unit
      generic map (N_CAMS => N_CAMS_MU(i+1), BASE_ADDR => BASE_ADDR + 20 + 2*i)
      port map (clk => clk, ctrl_i => mu_ctrl(i),
                step_count_o => step_count(10 + i),
                step_count_set_o => step_count_set_done(10 + i),
                w_o => mu(i),
                cmd_ctrl_i => cmd_ctrl_i, cmd_ctrl_o => subtgt_ctrl_o(10 + i));
  end generate;

  enable_sequencer : entity work.Enable_Sequencer
    generic map (N_OUTPUTS => N_WHEELS)
    port map (clk => clk,
              en_adv_i => step_counts_set_adv_i,
              en_o => step_count_set_req);

  -- Combine move controls:
  move_rst <= manual_move_rst or auto_move_rst;
  move_en <= manual_move_en or move_en_i;

  -- Individual wheel control inputs:
  auto_control : process (move_rst, move_en, mu, step_counts_i, step_count_set_req)
  is
  begin
    for i in 0 to 4 loop
      chi_ctrl(i).move_rst <= move_rst;
      chi_ctrl(i).move_en <= move_en;
      chi_ctrl(i).step_count <= step_counts_i;
      chi_ctrl(i).step_count_set <= step_count_set_req(i);
    end loop;

    for i in 0 to 4 loop
      psi_ctrl(i).move_rst <= move_rst;
      psi_ctrl(i).move_en <= move_en and mu(1);
      psi_ctrl(i).step_count <= step_counts_i;
      psi_ctrl(i).step_count_set <= step_count_set_req(5+i);
    end loop;

    for i in 0 to 1 loop
      mu_ctrl(i).move_rst <= move_rst;
      mu_ctrl(i).step_count <= step_counts_i;
      mu_ctrl(i).step_count_set <= step_count_set_req(10+i);
    end loop;

    mu_ctrl(0).move_en <= move_en;
    mu_ctrl(1).move_en <= move_en and mu(0);
  end process auto_control;

  -- Output streams:
  chi_o <= chi;
  psi_o <= psi;
  mu_o <= mu;

  -- The whole panel has set the stepping-vector when the last wheel has.
  step_counts_set_done_o <= step_count_set_done(N_WHEELS-1);

  move_reset_protocol : process (clk)
  is
    type FSM_State_t is (Idle, Reset_Over, Delay, Assert_Done_Start);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          move_reset_done_o <= '0';
          if move_reset_req_i = '1' then
            auto_move_rst <= '1';
            state := Reset_Over;
          else
            auto_move_rst <= '0';
          end if;
        when Reset_Over =>
          auto_move_rst <= '0';
          state := Delay;
        when Delay =>
          -- Delay might not be necessary?
          state := Assert_Done_Start;
        when Assert_Done_Start =>
          move_reset_done_o <= '1';
          state := Idle;
      end case;
    end if;
  end process move_reset_protocol;

  access_step_counters : process (clk)
  is
    variable i_step_count_sel : integer;
  begin
    if rising_edge(clk) then
      i_step_count_sel := to_integer(step_count_sel_i);

      if i_step_count_sel < N_WHEELS then
        step_count_val_o <= step_count(i_step_count_sel);
      else
        step_count_val_o <= CAM_WHEEL_STEP_COUNT_ZERO;
      end if;
    end if;
  end process access_step_counters;

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Cmd_Done, Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          subtgt_ctrl_o(N_WHEELS) <= CTRL_BUS_FR_TARGET_ZERO;
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = BASE_ADDR + 2 * N_WHEELS then
              subtgt_ctrl_o(N_WHEELS).busy <= '1';

              -- 0x00 Reset movement
              -- 0x01 Enable movement (one-shot)
              -- 0x10 Read CHI
              -- 0x11 Read PSI
              -- 0x12 Read MU

              case cmd_ctrl_i.data is
                when x"00" =>
                  manual_move_rst <= '1';
                  cmd_success_code := x"70";
                  state := Cmd_Done;
                when x"01" =>
                  manual_move_en <= '1';
                  cmd_success_code := x"71";
                  state := Cmd_Done;
                when x"10" =>
                  cmd_success_code := "000" & chi;
                  state := Cmd_Done;
                when x"11" =>
                  cmd_success_code := "000" & psi;
                  state := Cmd_Done;
                when x"12" =>
                  cmd_success_code := "000000" & mu;
                  state := Cmd_Done;
                when others =>
                  state := Bad_Sub_Cmd;
              end case;
            end if;
          else
          end if;
        when Cmd_Done =>
          manual_move_rst <= '0';
          manual_move_en <= '0';
          ctrl_cmd_success(subtgt_ctrl_o(N_WHEELS), cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(subtgt_ctrl_o(N_WHEELS), x"7f");
          state := Idle;
      end case;
    end if;
  end process command_target;

  reduce_ctrl_out : process (subtgt_ctrl_o)
  is
    variable v_bus : Ctrl_Bus_Fr_Target_t;
  begin
    v_bus := CTRL_BUS_FR_TARGET_ZERO;

    for i in subtgt_ctrl_o'range loop
      v_bus := v_bus or subtgt_ctrl_o(i);
    end loop;

    cmd_ctrl_o <= v_bus;
  end process;

end architecture behaviour;
