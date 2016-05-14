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

library IEEE;
library work;
library std;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use work.types.all;
use work.utils.all;

------------------------------------------------------------------------------

-- Top-level REPL for unit-testing via simulation.

------------------------------------------------------------------------------

entity monitor is
end entity monitor;

architecture behaviour of monitor is

  signal global_clk_en  : std_logic            := '1';
  constant clk_period   : time                 := 10ns;
  signal clk            : std_logic            := '0';
  --
  signal data_addr_muxd : RPi_Data_Addr_Muxd_t := (others => '0');
  signal data_addr_sel  : std_logic            := '0';
  signal req            : std_logic            := '0';
  --
  signal busy           : std_logic;
  signal response_err   : std_logic;
  signal response       : RPi_Response_t;

begin

  rpi_colossus : entity work.RPi_Colossus
    port map (
      clk            => clk,
      data_addr_muxd => data_addr_muxd,
      data_addr_sel  => data_addr_sel,
      req            => req,
      busy           => busy,
      resp_err       => response_err,
      resp           => response);

  drive_clock : process
  is
  begin
    if global_clk_en = '1' then
      clk <= '1';
      wait for clk_period / 2;
      clk <= '0';
      wait for clk_period / 2;
    else
      wait;
    end if;
  end process drive_clock;

  repl : process
  is
    file in_cmd_file : text open read_mode is "/tmp/repl-input";
    variable file_line : line;
    variable file_chr : character;
    variable file_chr_valid : boolean;
    variable cmd : std_logic_vector(15 downto 0) := (others => 'X');
    variable cmd_idx : integer range 0 to 4;
    variable cmd_bit_idx_0 : integer range 0 to 15;
    variable cmd_bit_idx_1 : integer range 0 to 15;
    variable vld_nbl : std_logic_vector(4 downto 0);
    variable input_valid_p : boolean;
    variable out_line : line;

    procedure submit_data (
      constant data : in RPi_Data_Addr_Muxd_t)
    is
    begin
      data_addr_muxd <= data;
      data_addr_sel  <= '1';
      wait for 2 * clk_period + 2ns;

      req <= '1';
      wait until busy = '1';
      wait for 2 * clk_period + 2ns;

      req <= '0';
      wait until busy = '0';
    end procedure submit_data;

    procedure submit_addr_data (
      constant addr : in RPi_Data_Addr_Muxd_t;
      constant data : in RPi_Data_Addr_Muxd_t)
    is
    begin  -- procedure submit_request
      data_addr_muxd <= addr;
      data_addr_sel  <= '0';
      wait for 2 * clk_period + 2ns;

      req <= '1';
      wait until busy = '1';
      wait for 2 * clk_period + 2ns;

      req <= '0';
      wait until busy = '0';
      wait for 2 * clk_period;

      submit_data(data);
    end procedure submit_addr_data;
  begin
    wait for 3 * clk_period;
    wait until falling_edge(clk);

    write(out_line, "READY-FOR-INPUT");
    writeline(output, out_line);

    while not endfile(in_cmd_file)
    loop
      readline(in_cmd_file, file_line);

      read(file_line, file_chr, file_chr_valid);
      write(out_line, "COLOSSUS-RESPONSE: ");
      cmd_idx := 0;
      while file_chr_valid and (cmd_idx <= 3) loop
        write(out_line, file_chr);      -- echo command as we go
        vld_nbl := validated_nibble(file_chr);
        exit when vld_nbl(4) = '1';

        cmd_bit_idx_0 := (4 - cmd_idx) * 4 - 1;
        cmd_bit_idx_1 := (3 - cmd_idx) * 4;
        cmd(cmd_bit_idx_0 downto cmd_bit_idx_1) := vld_nbl(3 downto 0);

        read(file_line, file_chr, file_chr_valid);
        cmd_idx := cmd_idx + 1;
      end loop;

      write(out_line, " ");

      input_valid_p := false;
      if vld_nbl(4) = '0' then
        case cmd_idx is
          when 2 => submit_data(cmd(15 downto 8));
                    input_valid_p := true;
          when 4 => submit_addr_data(cmd(15 downto 8), cmd(7 downto 0));
                    input_valid_p := true;
          when others => null;
        end case;
      end if;

      if input_valid_p then
        write(out_line, std_logic'image(response_err));
        write(out_line, " ");
        write(out_line, to_integer(unsigned(response)));
      else
        write(out_line, "?");
      end if;

      writeline(output, out_line);
    end loop;

    wait for 5 * clk_period;
    global_clk_en <= '0';
    wait;
  end process repl;

end architecture behaviour;
