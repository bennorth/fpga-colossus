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

------------------------------------------------------------------------

-- Simple pipeline component, taking an input and working on it to produce an
-- output.  Its input is on the 'left' and output on the 'right'.  Data-slot
-- ownership/state is governed by 'rdy' / 'bsy', and cycles through the
-- following:
--
-- rdy = '0', bsy = '0': owned by the producer, which has not yet completely
-- performed its task (in fact the producer might not even have started work)
--
-- rdy = '1', bsy = '0': owned by the producer, which has finished its task (the
-- slot therefore contains the result of the computation)
--
-- rdy = '1', bsy = '1': in the process of having ownership transferred to the
-- consumer
--
-- rdy = '0', bsy = '1': owned by the consumer, which can mutate the contents of
-- the slot if required
--
-- To direct the worker to consume the input and produce the output, the
-- scheduler asserts 'work_req_o' for one cycle, then waits for 'work_done_i'.
--
-- Workers sometimes are done in 'pull' fashion:  The component implementing the
-- output slot tells the component implementing the input slot what to do.
-- E.g., the comparator panel pulls its 'counter comparands' from the counter
-- panel.
--
-- Other workers operate via 'push':  The implementor of the input slot emits
-- commands to the implementor of the output slot to accept new data.  E.g., the
-- step-count-vector issues commands to one body's cam wheels panel to configure
-- new stepping settings.
--
-- More complex pipeline schedulers are in the other files in this directory:
--
-- 'Tee': queued_datum_controller_tee.vhd
-- 'Join': queued_datum_controller_join.vhd
-- 'Iterate Source': queued_datum_controller_generator_source.vhd
-- 'Collect Sink': queued_datum_controller_collector_sink.vhd
-- 'Distribute': queued_datum_controller_distributor.vhd
--
-- The worker request protocol for 'Distribute' and 'Collect Sink' is more
-- complex as these schedulers need to be able to request work from one of a
-- collection of workers.  This is done by augmenting the 'req' and 'done'
-- lines with an 'idx' signal.

------------------------------------------------------------------------

entity Queued_Datum_Controller_Pipe is
  port (
    clk         : in  std_logic;
    --
    left_rdy_i  : in  std_logic;
    left_bsy_o  : out std_logic;
    right_rdy_o : out std_logic;
    right_bsy_i : in  std_logic;
    --
    work_req_o  : out std_logic;
    work_done_i : in  std_logic);
end entity Queued_Datum_Controller_Pipe;


architecture behaviour of Queued_Datum_Controller_Pipe is
    signal wbsy : std_logic := '0';
begin

  control : process (clk) is
    type FSM_State_t is (Awaiting_Input_Ready,
                         Awaiting_Input_Acquisition_Acknowledge,
                         Awaiting_Output_Space,
                         Requesting_Work,
                         Awaiting_Work_Completion,
                         Awaiting_Output_Handover);
    variable state : FSM_State_t := Awaiting_Input_Ready;
  begin
    if rising_edge(clk) then
      case state is
        when Awaiting_Input_Ready =>
          right_rdy_o <= '0';
          work_req_o <= '0';
          if left_rdy_i = '1' then
            left_bsy_o <= '1';
            state := Awaiting_Input_Acquisition_Acknowledge;
          else
            left_bsy_o <= '0';
          end if;
        when Awaiting_Input_Acquisition_Acknowledge =>
          if left_rdy_i = '0' then
            state := Awaiting_Output_Space;
          end if;
        when Awaiting_Output_Space =>
          if right_bsy_i = '0' then
            work_req_o <= '1';
            state := Requesting_Work;
          end if;
        when Requesting_Work =>
          wbsy <= '1';
          work_req_o <= '0';
          state := Awaiting_Work_Completion;
        when Awaiting_Work_Completion =>
          if work_done_i = '1' then
            right_rdy_o <= '1';
            left_bsy_o <= '0';
            wbsy <= '0';
            state := Awaiting_Output_Handover;
          end if;
        when Awaiting_Output_Handover =>
          if right_bsy_i = '1' then
            state := Awaiting_Input_Ready;
          end if;
      end case;
    end if;
  end process control;

end architecture behaviour;
