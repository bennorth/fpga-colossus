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
use ieee.numeric_std.all;
use work.types.all;
use work.utils.all;

-------------------------------------------------------------------------------

-- The Comparator_Panel implements the 'load counter values' worker, which
-- transfers the 'latched counters' from the counter panel to the 'counter
-- comparands'.  (So called because they will be compared to the 'set total'
-- thresholds.)  To do so it uses the memory-like interface provided by the
-- Counter_Panel to the 'latched' values of its five Counter instances.
--
-- Similarly, the Comparator_Panel fetches and stores the current stepping
-- counts into the 'stepping labels'.  This is done via the memory-like
-- interface Cam_Wheels_Panel provides to its wheels' step-counts.
--
-- The 'maybe print' worker is implemented in two processes:
--
-- perform_comparisons: Each counter is continuously compared to its threshold
-- in the appropriate sense (greater-than or less-than), and if any counter
-- meets its condition, 'print_required' is asserted.
--
-- maybe_print_record: When 'maybe print' is requested, 'print_required' is
-- checked, and if printing is indeed required, a stream of octets is written to
-- the printer-control bus.  The 'maybe print' worker is an 'indexed worker', so
-- we check whether the command is for our body before acting.
--
-- The per-body 'counter comparands' data-slot is implemented in the
-- 'counter_values' signal; the per-body 'stepping labels' data-slot in the
-- 'step_count_labels' signal.
--
-- The per-body 'printer record' data-slot is conceptual only; as soon as the
-- 'counter comparands' and 'stepping labels' are available, so is the 'printer
-- record'.

-------------------------------------------------------------------------------

entity Comparator_Panel is

  generic (
    BASE_ADDR : integer;
    BODY_ID : Cam_Wheel_Step_Count_t);

  port (
    clk                     : in  std_logic;
    --
    step_count_sel_o        : out Cam_Wheel_Addr_t;
    step_count_val_i        : in  Cam_Wheel_Step_Count_t;
    --
    copy_settings_req       : in  std_logic;
    copy_settings_done      : out std_logic;
    --
    counter_sel_o           : out Counter_Addr_t;
    counter_val_i           : in  Counter_Value_t;
    --
    copy_counter_vals_req   : in  std_logic;
    copy_counter_vals_done  : out std_logic;
    --
    printer_write_en        : out std_logic;
    printer_write_data      : out Printer_RAM_Data_t;
    --
    maybe_print_record_idx  : in  Cam_Wheel_Step_Count_t;
    maybe_print_record_req  : in  std_logic;
    maybe_print_record_done : out std_logic;
    --
    cmd_ctrl_i              : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o              : out Ctrl_Bus_Fr_Target_t);

end entity Comparator_Panel;

architecture behaviour of Comparator_Panel is

  signal step_count_labels : Cam_Wheel_Step_Count_Vec_t(0 to N_WHEELS-1)
    := (others => CAM_WHEEL_STEP_COUNT_ZERO);
  signal wheel_idx_req : integer range 0 to N_WHEELS-1;
  signal wheel_idx_got : integer range 0 to N_WHEELS-1;

  signal counter_values : Counter_Value_Vec_t(0 to N_COUNTERS-1)
    := (others => COUNTER_VALUE_ZERO);
  signal counter_addr_req : integer range 0 to N_COUNTERS-1;
  signal counter_addr_got : integer range 0 to N_COUNTERS-1;

  signal raw_cfg : std_logic_vector((2 * N_COUNTERS * 8)-1 downto 0);
  signal cfg : Set_Total_Cfg_Vec_t(0 to N_COUNTERS-1);

  -- 0 --- config registers
  -- 1 --- read stored values
  signal subcmd_ctrl_o : Ctrl_Bus_Fr_Target_Vec_t(0 to 1);

  signal counter_value_gt_threshold : Counter_1b_Vec_t := (others => '0');
  signal counter_value_lt_threshold : Counter_1b_Vec_t := (others => '0');
  signal print_required_vec : Counter_1b_Vec_t := (others => '0');
  signal print_required : std_logic := '0';

begin

  cfg_reg : entity work.Generic_Config_Register
    generic map (BASE_ADDR => BASE_ADDR + 2, N_OCTETS => 2 * N_COUNTERS)
    port map (clk => clk,
              ctrl_i => cmd_ctrl_i, ctrl_o => subcmd_ctrl_o(0),
              cfg_o => raw_cfg);

  unpack_cfg : process (raw_cfg)
  is
    variable bit_idx : integer;
    variable op_bits : std_logic_vector(1 downto 0);
  begin
    for i in 0 to N_COUNTERS-1 loop
      bit_idx := 16 * i;
      cfg(i).threshold <= unsigned(raw_cfg((bit_idx + 13) downto bit_idx));
      op_bits := raw_cfg((bit_idx + 15) downto (bit_idx + 14));
      if op_bits = "00" then
        cfg(i).operation <= Count_GT_Threshold;
      elsif op_bits = "01" then
        cfg(i).operation <= Count_LT_Threshold;
      else
        cfg(i).operation <= Always_True;
      end if;
    end loop;
  end process unpack_cfg;

  copy_settings_worker : process(clk)
  is
    type FSM_State_t is (Idle, Pipeline_Filling, Pipeline_Flowing, Pipeline_Draining);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          wheel_idx_req <= 0;
          wheel_idx_got <= 0;
          step_count_sel_o <= (others => '0');
          copy_settings_done <= '0';
          if copy_settings_req = '1' then
            state := Pipeline_Filling;
          end if;
        when Pipeline_Filling =>
          wheel_idx_got <= 0;
          step_count_sel_o <= cam_wheel_addr_f_int(1);
          wheel_idx_req <= 2;
          state := Pipeline_Flowing;
        when Pipeline_Flowing =>
          step_count_labels(wheel_idx_got) <= step_count_val_i;
          wheel_idx_got <= wheel_idx_got + 1;
          if wheel_idx_req = 0 then
            state := Pipeline_Draining;
          else
            step_count_sel_o <= cam_wheel_addr_f_int(wheel_idx_req);
            if wheel_idx_req = N_WHEELS-1 then
              wheel_idx_req <= 0;
            else
              wheel_idx_req <= wheel_idx_req + 1;
            end if;
          end if;
        when Pipeline_Draining =>
          step_count_labels(wheel_idx_got) <= step_count_val_i;
          copy_settings_done <= '1';
          state := Idle;
      end case;
    end if;
  end process copy_settings_worker;

  -- I promise I tried quite hard to abstract this into a component, but the
  -- requirement to have a 'vector of vectors' as an output port generated lots
  -- of Google hits but nothing useful.
  --
  copy_counter_values_worker : process(clk)
  is
    type FSM_State_t is (Idle, Pipeline_Filling, Pipeline_Flowing, Pipeline_Draining);
    variable state : FSM_State_t := Idle;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          counter_addr_req <= 0;
          counter_addr_got <= 0;
          counter_sel_o <= (others => '0');
          copy_counter_vals_done <= '0';
          if copy_counter_vals_req = '1' then
            state := Pipeline_Filling;
          end if;
        when Pipeline_Filling =>
          counter_addr_got <= 0;
          counter_sel_o <= counter_addr_f_int(1);
          counter_addr_req <= 2;
          state := Pipeline_Flowing;
        when Pipeline_Flowing =>
          counter_values(counter_addr_got) <= counter_val_i;
          counter_addr_got <= counter_addr_got + 1;
          if counter_addr_req = 0 then
            state := Pipeline_Draining;
          else
            counter_sel_o <= counter_addr_f_int(counter_addr_req);
            if counter_addr_req = N_COUNTERS-1 then
              counter_addr_req <= 0;
            else
              counter_addr_req <= counter_addr_req + 1;
            end if;
          end if;
        when Pipeline_Draining =>
          counter_values(counter_addr_got) <= counter_val_i;
          copy_counter_vals_done <= '1';
          state := Idle;
      end case;
    end if;
  end process copy_counter_values_worker;

  perform_comparisons : process (clk)
  is
    variable i : integer;
    variable tmp_print_required : std_logic;
  begin
    if rising_edge(clk) then
      -- Three-stage pipeline; might not be necessary but try it.

      -- Stage 0:  Perform all comparisons.
      for i in 0 to N_COUNTERS-1 loop
        if counter_values(i) > cfg(i).threshold then
          counter_value_gt_threshold(i) <= '1';
        else
          counter_value_gt_threshold(i) <= '0';
        end if;
        if counter_values(i) < cfg(i).threshold then
          counter_value_lt_threshold(i) <= '1';
        else
          counter_value_lt_threshold(i) <= '0';
        end if;
      end loop;

      -- Stage 1:  From comparison results, get 'print required' vector.
      for i in 0 to N_COUNTERS-1 loop
        case cfg(i).operation is
          when Count_GT_Threshold =>
            print_required_vec(i) <= counter_value_gt_threshold(i);
          when Count_LT_Threshold =>
            print_required_vec(i) <= counter_value_lt_threshold(i);
          when Always_True =>
            print_required_vec(i) <= '1';
        end case;
      end loop;

      -- Stage 2:  Reduce down to single 'print required' value.
      tmp_print_required := '0';
      for i in 0 to N_COUNTERS-1 loop
        if print_required_vec(i) = '1' then
          tmp_print_required := '1';
        end if;
      end loop;
      print_required <= tmp_print_required;
    end if;
  end process perform_comparisons;

  -- 'maybe print' worker:
  --
  -- if 'print_required', then emit a record of octets to the printer,
  -- describing the 12 current stepping values of the wheels and the 5 current
  -- counter values.  If not 'print_required', signal 'done' immediately.
  --
  maybe_print_record : process (clk)
  is
    type FSM_State_t is (Idle,
                         Checking_Whether_To_Print,
                         Await_Pipeline_Completion,
                         Printing_Body_Id,
                         Printing_Step_Count_Labels,
                         Printing_Counter_Values_L, Printing_Counter_Values_H,
                         Work_Done);
    variable state : FSM_State_t := Idle;
    variable step_count_label_idx : integer range 0 to N_WHEELS-1 := 0;
    variable counter_value_idx : integer range 0 to N_COUNTERS-1 := 0;
    variable cmp_latency_remaining : integer range 0 to 3 := 0;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          printer_write_en <= '0';
          printer_write_data <= PRINTER_RAM_DATA_ZERO;
          maybe_print_record_done <= '0';
          if (maybe_print_record_req = '1' and maybe_print_record_idx = BODY_ID) then
            cmp_latency_remaining := 3;
            state := Await_Pipeline_Completion;
          end if;
        when Await_Pipeline_Completion =>
          if cmp_latency_remaining = 0 then
            state := Checking_Whether_To_Print;
          else
            cmp_latency_remaining := cmp_latency_remaining - 1;
          end if;
        when Checking_Whether_To_Print =>
          if print_required = '1' then
            step_count_label_idx := 0;
            counter_value_idx := 0;
            state := Printing_Body_Id;
          else
            state := Work_Done;
          end if;
        when Printing_Body_Id =>
            printer_write_en <= '1';
            printer_write_data <= "00" & std_logic_vector(BODY_ID);
            state := Printing_Step_Count_Labels;
        when Printing_Step_Count_Labels =>
          printer_write_data
            <= "00" & std_logic_vector(step_count_labels(step_count_label_idx));
          if step_count_label_idx = N_WHEELS-1 then
            state := Printing_Counter_Values_L;
          else
            step_count_label_idx := step_count_label_idx + 1;
          end if;
        when Printing_Counter_Values_L =>
          printer_write_data
            <= std_logic_vector(counter_values(counter_value_idx)(7 downto 0));
          state := Printing_Counter_Values_H;
        when Printing_Counter_Values_H =>
          printer_write_data
            <= "00" & std_logic_vector(counter_values(counter_value_idx)(13 downto 8));
          if counter_value_idx = N_COUNTERS-1 then
            state := Work_Done;
          else
            counter_value_idx := counter_value_idx + 1;
            state := Printing_Counter_Values_L;
          end if;
        when Work_Done =>
          printer_write_en <= '0';
          maybe_print_record_done <= '1';
          state := Idle;
      end case;
    end if;
  end process maybe_print_record;

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Awaiting_Comparison_Pipeline, Cmd_Done, Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable wheel_idx : integer range 0 to N_WHEELS-1;
    variable counter_idx : integer;
    variable cmd_success_code : Ctrl_Response_t;
    variable cmp_latency_remaining : integer range 0 to 3 := 0;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          subcmd_ctrl_o(1) <= CTRL_BUS_FR_TARGET_ZERO;
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = BASE_ADDR then
              subcmd_ctrl_o(1).busy <= '1';
              -- 0x0n Read step_count_labels(n) (or zero if n >= N_WHEELS)
              -- 0x2n Read low half of counter_values(n) (or zero if n >= N_COUNTERS)
              -- 0x3n Read high half of counter_values(n) (or zero if n >= N_COUNTERS)
              -- 0x40 Read 'count > threshold' bits
              -- 0x41 Read 'count < threshold' bits
              -- 0x42 Read 'print required' bit
              -- 0x4x (others) Reserved
              --
              if cmd_ctrl_i.data(7 downto 4) = x"0" then
                wheel_idx := to_integer(unsigned(cmd_ctrl_i.data(3 downto 0)));
                if wheel_idx < N_WHEELS then
                  cmd_success_code
                    := "00" & std_logic_vector(step_count_labels(wheel_idx));
                  state := Cmd_Done;
                else
                  state := Bad_Sub_Cmd;
                end if;
              --
              elsif cmd_ctrl_i.data(7 downto 5) = "001" then
                counter_idx := to_integer(unsigned(cmd_ctrl_i.data(3 downto 0)));
                if counter_idx < N_COUNTERS then
                  if cmd_ctrl_i.data(4) = '0' then
                    cmd_success_code
                      := std_logic_vector(counter_values(counter_idx)(7 downto 0));
                  else
                    cmd_success_code
                      := ("00"
                          & std_logic_vector(counter_values(counter_idx)(13 downto 8)));
                  end if;
                  state := Cmd_Done;
                else
                  state := Bad_Sub_Cmd;
                end if;
              --
              elsif cmd_ctrl_i.data(7 downto 4) = x"4" then
                cmp_latency_remaining := 3;
                state := Awaiting_Comparison_Pipeline;
              else
                state := Bad_Sub_Cmd;
              end if;
            end if;
          else
            subcmd_ctrl_o(1) <= CTRL_BUS_FR_TARGET_ZERO;
          end if;
        when Awaiting_Comparison_Pipeline =>
          if cmp_latency_remaining = 0 then
            case cmd_ctrl_i.data(3 downto 0) is
              when x"0" =>
                cmd_success_code := "000" & counter_value_gt_threshold;
                state := Cmd_Done;
              when x"1" =>
                cmd_success_code := "000" & counter_value_lt_threshold;
                state := Cmd_Done;
              when x"2" =>
                cmd_success_code := "000" & print_required_vec;
                state := Cmd_Done;
              when x"3" =>
                cmd_success_code := "0000000" & print_required;
                state := Cmd_Done;
              when others =>
                state := Bad_Sub_Cmd;
            end case;
          else
            cmp_latency_remaining := cmp_latency_remaining - 1;
          end if;
        when Cmd_Done =>
          ctrl_cmd_success(subcmd_ctrl_o(1), cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(subcmd_ctrl_o(1), x"ab");
          state := Idle;
      end case;
    end if;
  end process command_target;

  cmd_ctrl_o <= subcmd_ctrl_o(0) or subcmd_ctrl_o(1);

end architecture behaviour;
