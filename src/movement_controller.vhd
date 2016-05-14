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

-- The 'run tape once' worker is implemented here.  The BRAM configuration used
-- for the tape means there is a 3-cycle start-up latency between presenting the
-- first address and getting the first data.  Further latencies through the
-- other components mean that some care is needed to enable the components
-- (cam-wheel movement, Q-selector, counters) at the right times.  See inline
-- comments below.  Once the 'pipeline' is full, computation proceeds at one
-- tape letter per cycle.

-------------------------------------------------------------------------------

entity Movement_Controller is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk           : in  std_logic;
    --
    cmd_ctrl_i    : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o    : out Ctrl_Bus_Fr_Target_t;
    --
    run_tape_once_req  : in  std_logic;
    run_tape_once_done : out std_logic;
    --
    reset_wheels_movement_req_o  : out std_logic;
    reset_wheels_movement_done_i : in std_logic;
    --
    q_delta_i : in std_logic;
    z_stop_i : in std_logic;
    bedstead_ctrl_o : out Ctrl_Bus_To_Bedstead_t;
    cam_wheel_ctrl_o : out Cam_Wheel_Ctrl_t;
    q_sel_ctrl_o     : out Q_Selector_Ctrl_t;
    counter_ctrl_o : out Counter_Ctrl_t);

end entity Movement_Controller;

architecture behaviour of Movement_Controller is

  signal bedstead_ctrl : Ctrl_Bus_To_Bedstead_Vec_t(0 to 1)
    := (others => CTRL_BUS_TO_BEDSTEAD_ZERO);

  signal q_sel_ctrl : Q_Selector_Ctrl_Vec_t(0 to 1)
    := (others => Q_SELECTOR_CTRL_ZERO);

  signal counter_ctrl : Counter_Ctrl_Vec_t(0 to 1)
    := (others => COUNTER_CTRL_ZERO);

  signal cam_wheel_ctrl : Cam_Wheel_Ctrl_Vec_t(0 to 1)
    := (others => CAM_WHEEL_CTRL_ZERO);

begin

  control : process (clk)
  is
    type FSM_State_t is (Idle,
                         Reset_Movement_Wheels, Reset_Movement_Wheels_Await_Done,
                         Reset_Movement, Move_One_Sprocket, Bad_Movement);
    variable state : FSM_State_t := Idle;
    variable pc : integer range 0 to 15;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              case cmd_ctrl_i.data is
                when x"00" =>
                  state := Reset_Movement_Wheels;
                when x"01" =>
                  state := Move_One_Sprocket;
                when others =>
                  state := Bad_Movement;
              end case;
              pc := 0;
            end if;
          else
            cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
            bedstead_ctrl(0) <= CTRL_BUS_TO_BEDSTEAD_ZERO;
            q_sel_ctrl(0) <= Q_SELECTOR_CTRL_ZERO;
            counter_ctrl(0) <= COUNTER_CTRL_ZERO;
            cam_wheel_ctrl(0) <= CAM_WHEEL_CTRL_ZERO;
          end if;
        when Reset_Movement_Wheels =>
          reset_wheels_movement_req_o <= '1';
          state := Reset_Movement_Wheels_Await_Done;
        when Reset_Movement_Wheels_Await_Done =>
          reset_wheels_movement_req_o <= '0';
          if reset_wheels_movement_done_i = '1' then
            state := Reset_Movement;
          end if;
        when Reset_Movement =>
          case pc is
            when 0 =>
              bedstead_ctrl(0).mv_rst <= '1';
              q_sel_ctrl(0).rst <= '1';
            when 1 =>
              -- Tape_Operational_Controller resets address
              -- and cam wheels move-reset
              bedstead_ctrl(0).mv_rst <= '0';
              q_sel_ctrl(0).rst <= '0';
            when 2 | 3 | 4 =>
              -- 2. RAM reads from new address
              -- 3. RAM presents new data on primitive output latches
              -- 4. RAM presents new data on core output latches
              null;
            when 5 =>
              -- Tape_Operational_Controller latches RAM data to aug_z;
              -- enable Q_Selector, to process this new value
              q_sel_ctrl(0).en <= '1';
            when 6 =>
              q_sel_ctrl(0).en <= '0';
              ctrl_cmd_success(cmd_ctrl_o, x"61");
              state := Idle;
            when others =>
              state := Idle;
          end case;
          pc := pc + 1;
        when Move_One_Sprocket =>
          case pc is
            when 0 =>
              bedstead_ctrl(0).mv_en <= '1';
              cam_wheel_ctrl(0).move_en <= '1';
            when 1 =>
              -- Tape_Operational_Controller advances address
              -- and cam wheels move one sprocket
              bedstead_ctrl(0).mv_en <= '0';
              cam_wheel_ctrl(0).move_en <= '0';
            when 2 | 3 | 4 =>
              -- 2. RAM reads from new address
              -- 3. RAM presents new data on primitive output latches
              -- 4. RAM presents new data on core output latches
              null;
            when 5 =>
              -- Tape_Operational_Controller latches RAM data to aug_z;
              -- enable Q_Selector, to process this new value
              q_sel_ctrl(0).en <= '1';
            when 6 =>
              q_sel_ctrl(0).en <= '0';
              ctrl_cmd_success(cmd_ctrl_o, x"63");
              state := Idle;
            when others =>
              state := Idle;
          end case;
          pc := pc + 1;
        when Bad_Movement =>
          ctrl_cmd_failure(cmd_ctrl_o, x"98");
          state       := Idle;
      end case;
    end if;
  end process control;

  run_tape_once_worker : process (clk)
  is
    type FSM_State_t is (Idle, Start, Run, Finish);
    variable state : FSM_State_t := Idle;
    variable pc : integer range 0 to 15 := 0;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          run_tape_once_done <= '0';
          if run_tape_once_req = '1' then
            pc := 0;
            state := Start;
          end if;
        when Start =>
          case pc is
            when 0 =>
              bedstead_ctrl(1).mv_rst <= '1';
              q_sel_ctrl(1).rst <= '1';
              counter_ctrl(1).count_rst <= '1';
            when 1 =>
              -- Tape_Operational_Controller resets address
              -- and cam wheels move-reset
              bedstead_ctrl(1).mv_rst <= '0';
              bedstead_ctrl(1).mv_en <= '1';
              q_sel_ctrl(1).rst <= '0';
              counter_ctrl(1).count_rst <= '0';
            when 2 | 3 | 4 =>
              -- 2. RAM reads from zeroth address
              -- 3. RAM reads data[1];
              --    data[0] on primitive output latches
              -- 4. RAM reads data[2];
              --    data[1] on primitive output latches;
              --    data[0] on core output latches
              null;
            when 5 =>
              -- 5. RAM reads data[3];
              --    data[2] on primitive output latches;
              --    data[1] on core output latches
              -- Tape_Operational_Controller latches data[0] to aug_z;
              -- chi[0] / psi[0] available up til now; enable movement
              -- to get next CHI/PSI with data[1] on following cycle;
              cam_wheel_ctrl(1).move_en <= '1';
              -- enable Q_Selector, to process this new value
              q_sel_ctrl(1).en <= '1';
            when 6 | 7 =>
              -- 6. presented on Q
              -- 7. presented on summand_factors
              null;
            when 8 =>
              -- 8. presented on summands
              --    enable counters if Q-Selector config involves no DELTA
              if q_delta_i = '0' then
                counter_ctrl(1).count_en <= '1';
              end if;
            when 9 =>
              -- 9. enable counters anyway
              counter_ctrl(1).count_en <= '1';
            when others =>
              state := Run;
          end case;
          pc := pc + 1;
        when Run =>
          if z_stop_i = '1' then
            pc := 0;
            state := Finish;
          end if;
        when Finish =>
          case pc is
            when 0 =>
              -- Wait for pipeline to empty.  (Have already 'waited' one cycle
              -- in moving from previous state Run to Finish.)
              null;
            when 1 =>
              counter_ctrl(1).count_en <= '0';
            when 2 =>
              bedstead_ctrl(1) <= CTRL_BUS_TO_BEDSTEAD_ZERO;
              cam_wheel_ctrl(1).move_en <= '0';
              q_sel_ctrl(1) <= Q_SELECTOR_CTRL_ZERO;
              counter_ctrl(1) <= COUNTER_CTRL_ZERO;
              run_tape_once_done <= '1';
              state := Idle;
            when others =>
              state := Idle;
          end case;
          pc := pc + 1;
      end case;
    end if;
  end process run_tape_once_worker;

  bedstead_ctrl_o <= bedstead_ctrl(0) or bedstead_ctrl(1);
  q_sel_ctrl_o <= q_sel_ctrl(0) or q_sel_ctrl(1);
  counter_ctrl_o <= counter_ctrl(0) or counter_ctrl(1);
  cam_wheel_ctrl_o <= cam_wheel_ctrl(0) or cam_wheel_ctrl(1);

  -- Ground unused inputs.
  cam_wheel_ctrl(1).move_rst <= '0';
  cam_wheel_ctrl(1).step_count <= CAM_WHEEL_STEP_COUNT_ZERO;
  cam_wheel_ctrl(1).step_count_set <= '0';

end architecture behaviour;
