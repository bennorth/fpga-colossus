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

entity Printer_Panel is

  generic (
    MAPPED_ADDR : integer);

  port (
    clk        : in  std_logic;
    --
    ctrl_i     : in  Printer_Write_Ctrl_t;
    --
    cmd_ctrl_i : in  Ctrl_Bus_To_Target_t;
    cmd_ctrl_o : out Ctrl_Bus_Fr_Target_t);

end entity Printer_Panel;

architecture behaviour of Printer_Panel is

  signal combined_write_ctrl : Printer_Write_Ctrl_t := PRINTER_WRITE_CTRL_ZERO;
  signal manual_write_ctrl : Printer_Write_Ctrl_t := PRINTER_WRITE_CTRL_ZERO;

  signal ram_write_en : std_logic := '0';
  signal ram_write_addr : Printer_RAM_Addr_t := PRINTER_RAM_ADDR_ZERO;
  signal ram_write_data : Printer_RAM_Data_t := PRINTER_RAM_DATA_ZERO;
  signal ram_n_octets_written : Printer_RAM_Addr_t := PRINTER_RAM_ADDR_ZERO;

  signal ram_read_addr : Printer_RAM_Addr_t := PRINTER_RAM_ADDR_ZERO;
  signal ram_read_data : Printer_RAM_Data_t := PRINTER_RAM_DATA_ZERO;

  constant N_RAM_READ_CYCLES        : integer := 3;
  signal n_read_latencies_remaining : integer range 0 to N_RAM_READ_CYCLES;

begin

  printer_ram : entity work.Printer_RAM
    port map (
      clka   => clk,
      wea(0) => ram_write_en,
      addra  => std_logic_vector(ram_write_addr),
      dina   => ram_write_data,
      clkb   => clk,
      addrb  => std_logic_vector(ram_read_addr),
      doutb  => ram_read_data);

  control : process (clk)
  is
  begin
    if rising_edge(clk) then
      ram_write_en <= '0';

      if combined_write_ctrl.erase_en = '1' then
        ram_n_octets_written <= PRINTER_RAM_ADDR_ZERO;
        ram_write_addr <= PRINTER_RAM_ADDR_MAX_VALUE;
      elsif combined_write_ctrl.write_en = '1' then
        if ram_n_octets_written /= PRINTER_RAM_ADDR_MAX_VALUE then
          ram_write_data <= combined_write_ctrl.write_data;
          ram_write_en <= '1';
          ram_write_addr <= ram_write_addr + 1;
          ram_n_octets_written <= ram_n_octets_written + 1;
        end if;
      end if;
    end if;
  end process control;

  arbitrate_write_ctrl : process (ctrl_i, manual_write_ctrl)
  is
  begin
    if manual_write_ctrl.erase_en = '1' or manual_write_ctrl.write_en = '1' then
      combined_write_ctrl <= manual_write_ctrl;
    else
      combined_write_ctrl <= ctrl_i;
    end if;
  end process arbitrate_write_ctrl;

  command_target : process (clk)
  is
    type FSM_State_t is (Idle, Awaiting_Data_0, Awaiting_Data, Cmd_Done, Bad_Sub_Cmd);
    variable state : FSM_State_t := Idle;
    variable cmd_success_code : Ctrl_Response_t;
  begin
    if rising_edge(clk) then
      case state is
        when Idle =>
          cmd_ctrl_o <= CTRL_BUS_FR_TARGET_ZERO;
          manual_write_ctrl <= PRINTER_WRITE_CTRL_ZERO;

          if cmd_ctrl_i.wr_en = '1' then
            if cmd_ctrl_i.addr = MAPPED_ADDR then
              cmd_ctrl_o.busy <= '1';
              case cmd_ctrl_i.data is
                -- 0x00 Read low octet of 'number of characters'
                -- 0x01 Read high octet of 'number of characters'
                -- 0x02 Reset read pointer
                -- 0x03 Read character and advance read pointer
                when x"00" =>
                  cmd_success_code
                    := std_logic_vector(ram_n_octets_written(7 downto 0));
                  state := Cmd_Done;
                when x"01" =>
                  cmd_success_code
                    := "0000" & std_logic_vector(ram_n_octets_written(11 downto 8));
                  state := Cmd_Done;
                when x"02" =>
                  ram_read_addr <= (others => '0');
                  cmd_success_code := x"32";
                  state := Awaiting_Data_0;
                when x"03" =>
                  cmd_success_code := ram_read_data;
                  ram_read_addr <= ram_read_addr + 1;
                  state := Awaiting_Data_0;
                when others =>
                  state := Bad_Sub_Cmd;
              end case;
            elsif cmd_ctrl_i.addr = MAPPED_ADDR + 1 then
              -- Reset write pointer
              cmd_ctrl_o.busy <= '1';
              manual_write_ctrl.erase_en <= '1';
              cmd_success_code := x"11";
              state := Cmd_Done;
            elsif cmd_ctrl_i.addr = MAPPED_ADDR + 2 then
              -- Write character and advance
              cmd_ctrl_o.busy <= '1';
              manual_write_ctrl.write_en <= '1';
              manual_write_ctrl.write_data <= cmd_ctrl_i.data;
              cmd_success_code := x"12";
              state := Cmd_Done;
            end if;
          end if;
        when Awaiting_Data_0 =>
          -- "- 1" in following because one cycle already elapsed.
          n_read_latencies_remaining <= N_RAM_READ_CYCLES - 1;
          state                      := Awaiting_Data;
        when Awaiting_Data =>
          if n_read_latencies_remaining = 0 then
            state := Cmd_Done;
          else
            n_read_latencies_remaining <= n_read_latencies_remaining - 1;
          end if;
        when Cmd_Done =>
          manual_write_ctrl <= PRINTER_WRITE_CTRL_ZERO;
          ctrl_cmd_success(cmd_ctrl_o, cmd_success_code);
          state := Idle;
        when Bad_Sub_Cmd =>
          ctrl_cmd_failure(cmd_ctrl_o, x"76");
          state := Idle;
      end case;
    end if;
  end process command_target;

end architecture behaviour;
