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

------------------------------------------------------------------------------

entity Tape_Contents_Controller_Read_Tape is

  generic (
    MAPPED_ADDR : Ctrl_Addr_t);

  port (
    clk        : in  std_logic;
    --
    ctrl_i     : in  Ctrl_Bus_To_Target_t;
    ctrl_o     : out Ctrl_Bus_Fr_Target_t;
    --
    ram_ctrl_o : out Ctrl_Bus_To_RAM_t;
    ram_data_i : in  Tape_Loop_RAM_Data_t);

end entity Tape_Contents_Controller_Read_Tape;

architecture behaviour of Tape_Contents_Controller_Read_Tape is

  constant N_RAM_READ_CYCLES        : integer := 3;
  signal n_read_latencies_remaining : integer range 0 to N_RAM_READ_CYCLES;

begin

  read_tape_cmd : process (clk)
  is
    type FSM_State_t is (Idle, Read_Ptr_Reset,
                         Awaiting_Data_0, Awaiting_Data,
                         Bad_Read_Type);
    variable state     : FSM_State_t := Idle;
    variable read_addr : Tape_Loop_RAM_Addr_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          if ctrl_i.wr_en = '1' then
            if ctrl_i.addr = MAPPED_ADDR then
              ctrl_o.busy <= '1';
              case ctrl_i.data is
                when x"00" =>
                  read_addr       := ram_addr_f_int(0);
                  state           := Read_Ptr_Reset;
                when x"01" =>
                  ram_ctrl_o.req  <= '1';
                  ram_ctrl_o.addr <= read_addr;
                  read_addr       := read_addr + 1;
                  state           := Awaiting_Data_0;
                when others =>
                  state := Bad_Read_Type;
              end case;
            end if;
          else
            ctrl_o     <= CTRL_BUS_FR_TARGET_ZERO;
            ram_ctrl_o <= CTRL_BUS_TO_RAM_ZERO;
          end if;
        when Read_Ptr_Reset =>
          ctrl_cmd_success(ctrl_o, x"45");
          state := Idle;
        when Awaiting_Data_0 =>
          -- "- 1" in following because one cycle already elapsed.
          n_read_latencies_remaining <= N_RAM_READ_CYCLES - 1;
          state                      := Awaiting_Data;
        when Awaiting_Data =>
          if n_read_latencies_remaining = 0 then
            ctrl_cmd_success(ctrl_o, std_logic_vector(ram_data_i));
            state       := Idle;
          else
            n_read_latencies_remaining <= n_read_latencies_remaining - 1;
          end if;
        when Bad_Read_Type =>
          ctrl_cmd_failure(ctrl_o, x"98");
          state       := Idle;
      end case;
    end if;
  end process read_tape_cmd;

end architecture behaviour;

