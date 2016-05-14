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

-- A Step_Count_Vector implements the worker which passes the desired
-- step-counts to the desired body's cam-wheels.  This is done via a top-level
-- command bus, 'set_step_count_cmd', driven by the unique instance of
-- Step_Count_Vector in the head.  The idle state of this bus is all-bits-zero.
-- To command a particular body to set its cam-wheels to a particular set of
-- steppings, the Step_Count_Vector writes, on consecutive cycles:
--
-- a 'preamble' value (STEP_SET_CMD_PREAMBLE);
-- the target body-id;
-- the desired step-count for each of the twelve cam-wheels.
--
-- Each body listens to that bus, and the body's Cam_Wheels_Panel obeys
-- commands directed at its body's BODY_ID.  See comments in Cam_Wheels_Panel
-- for implementation.
--
-- The Step_Count_Vector component also implements the single 'step-count
-- vector' data-slot, within the head, in register 'counts'.
--
-- Note that we have separated the logic which changes the candidate wheel
-- steppings at the end of each tape run, from the cam-wheels which actually
-- have the stepped patterns.  The Step_Count_Vector only holds a vector of
-- integers ('counts'), updating it on 'next_req_i' according to the stepping
-- configuration (described next).  The process of setting the wheels' patterns
-- to the desired stepping is what was just described as happening via the
-- 'set_step_count_cmd' bus.
--
-- Stepping configuration is not quite the same as the real Colossus's switches
-- [53D(c),(d)], although all possible Colossus behaviours can be expressed.
-- The real Colossus has two three-position switches (upper and lower), but not
-- all of the nine resulting situations are fully described in GRT.  For
-- example, if both switches are 'up', the behaviour seems undefined, although
-- the wording is 'Either of these two switches may be thrown up or down',
-- suggesting that at most one switch can be in a non-neutral position.
--
-- We look at the four different bits of stepping behaviour:
--
-- 'fast': whether the wheel steps fast;
-- 'slow': whether the wheel steps slow;
-- 'trigger': whether the wheel triggers a slow-stepping wheel;
-- 'ign_rpt': whether the wheel is ignored for 'repeat lamp' purposes.
--
-- Assuming at most one real switch can be non-neutral, the five different
-- configurations on Colossus, and their equivalent configs here, are:
--
-- both neutral: fast='0', slow='0', trigger and ign_rpt ignored
-- upper switch up: fast='1', slow='0', trigger='0', ign_rpt='1'
-- upper switch down: fast='1', slow='0', trigger='0', ign_rpt='0'
-- lower switch up: fast='0', slow='1', trigger='0', ign_rpt='0'
-- lower switch down: fast='1', slow='0', trigger='1', ign_rpt='0'

------------------------------------------------------------------------------

entity Step_Count_Vector is

  port (
    clk             : in  std_logic;
    --
    reset_req_i     : in  std_logic;
    reset_done_o    : out std_logic;
    next_req_i      : in  std_logic;
    next_done_o     : out std_logic;
    next_ended_o    : out std_logic;
    --
    cfg             : in  Cam_Wheel_Step_Cfg_Vec_t(0 to N_WHEELS-1);
    --
    emit_tgt_i      : in  Cam_Wheel_Step_Count_t;
    emit_req_i      : in  std_logic;
    step_set_cmds_o : out Cam_Wheel_Step_Count_t;
    --
    element_sel_i   : in  Cam_Wheel_Addr_t;
    element_data_o  : out Cam_Wheel_Step_Count_t);

end entity Step_Count_Vector;

architecture behaviour of Step_Count_Vector is

  signal counts : Cam_Wheel_Step_Count_Vec_t(0 to N_WHEELS-1)
    := (others => CAM_WHEEL_STEP_COUNT_ZERO);
  signal count_eq_zero : std_logic_vector(0 to N_WHEELS-1);
  signal trigger_slow : std_logic := '0';

begin

  control : process (clk)
  is
    type FSM_State_t is (Idle,
                         Doing_Reset, Post_Reset_Delay, Start_Done_Reset,
                         Doing_Step,
                         Emitting_Cmd_Stream_Body_Id,
                         Emitting_Cmd_Stream_Tail);
    variable state : FSM_State_t := Idle;
    variable pc : integer range 0 to 2 := 0;
    variable emit_tgt : Cam_Wheel_Step_Count_t := CAM_WHEEL_STEP_COUNT_ZERO;
    variable emit_idx : integer range 0 to N_WHEELS-1 := 0;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          reset_done_o <= '0';
          next_done_o <= '0';
          step_set_cmds_o <= CAM_WHEEL_STEP_COUNT_ZERO;
          pc := 0;
          --
          if reset_req_i = '1' then
            state := Doing_Reset;
          elsif next_req_i = '1' then
            state := Doing_Step;
          elsif emit_req_i = '1' then
            step_set_cmds_o <= STEP_SET_CMD_PREAMBLE;
            emit_tgt := emit_tgt_i;
            state := Emitting_Cmd_Stream_Body_Id;
          end if;
        --
        when Doing_Reset =>
          for i in 0 to N_WHEELS-1 loop
            counts(i) <= CAM_WHEEL_STEP_COUNT_ZERO;
          end loop;
          state := Post_Reset_Delay;
        --
        when Post_Reset_Delay =>
          state := Start_Done_Reset;
        --
        when Start_Done_Reset =>
          reset_done_o <= '1';
          state := Idle;
        --
        when Doing_Step =>
          case pc is
            when 0 =>
              for i in 0 to N_WHEELS-1 loop
                if cfg(i).fast = '1' then
                  if counts(i) = N_CAMS_ALL(i) - 1 then
                    counts(i) <= CAM_WHEEL_STEP_COUNT_ZERO;
                  else
                    counts(i) <= counts(i) + 1;
                  end if;
                end if;
              end loop;
            --
            when 1 =>
              for i in 0 to N_WHEELS-1 loop
                if (cfg(i).slow and trigger_slow) = '1' then
                  if counts(i) = N_CAMS_ALL(i) - 1 then
                    counts(i) <= CAM_WHEEL_STEP_COUNT_ZERO;
                  else
                    counts(i) <= counts(i) + 1;
                  end if;
                end if;
              end loop;
            --
            when 2 =>
              next_done_o <= '1';
              state := Idle;
          end case;
          --
          pc := pc + 1;
        --
        when Emitting_Cmd_Stream_Body_Id =>
          step_set_cmds_o <= emit_tgt;
          emit_idx := 0;
          state := Emitting_Cmd_Stream_Tail;
        --
        when Emitting_Cmd_Stream_Tail =>
          step_set_cmds_o <= counts(emit_idx);
          if emit_idx = N_WHEELS-1 then
            state := Idle;
          else
            emit_idx := emit_idx + 1;
          end if;
      end case;
    end if;
  end process control;

  maintain_at_zero : process (counts)
  is
  begin
    for i in 0 to N_WHEELS-1 loop
      if counts(i) = 0 then
        count_eq_zero(i) <= '1';
      else
        count_eq_zero(i) <= '0';
      end if;
    end loop;
  end process;

  maintain_trigger_slow : process (count_eq_zero, cfg)
  is
    variable tmp : std_logic;
  begin
    tmp := '0';
    for i in 0 to N_WHEELS-1 loop
      tmp := tmp or (count_eq_zero(i) and cfg(i).fast and cfg(i).trigger);
    end loop;
    trigger_slow <= tmp;
  end process maintain_trigger_slow;

  maintain_next_ended : process (count_eq_zero, cfg)
  is
    variable tmp : std_logic;
  begin
    tmp := '1';
    for i in 0 to N_WHEELS-1 loop
      tmp := tmp and (count_eq_zero(i) or cfg(i).ign_rpt);
    end loop;
    next_ended_o <= tmp;
  end process maintain_next_ended;

  access_element : process(clk)
  is
    variable i_element_sel : integer;
  begin
    if rising_edge(clk) then
      i_element_sel := to_integer(element_sel_i);

      if i_element_sel < N_WHEELS then
        element_data_o <= counts(i_element_sel);
      else
        element_data_o <= (others => '0');
      end if;
    end if;
  end process access_element;

end architecture behaviour;
