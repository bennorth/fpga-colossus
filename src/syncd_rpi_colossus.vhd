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
use work.types.all;

------------------------------------------------------------------------------

entity Syncd_RPi_Colossus is

  port (
    clk            : in  std_logic;
    --
    data_addr_muxd : in  RPi_Data_Addr_Muxd_t;
    data_addr_sel  : in  std_logic;
    req_async      : in  std_logic;
    busy           : out std_logic;
    resp_err       : out std_logic;
    resp           : out RPi_Response_t);

end entity Syncd_RPi_Colossus;

architecture behaviour of Syncd_RPi_Colossus is

  -- sync 'request' input from outside world
  signal req : std_logic;
  -- connections from RPi_Interface to Colossus
  signal ctrl_to_cls : Ctrl_Bus_To_Target_t;
  -- connections from Colossus to RPi_Interface
  signal ctrl_fr_cls : Ctrl_Bus_Fr_Target_t;

begin

  req_synchronizer : entity work.synchronizer
    generic map (
      G_INIT_VALUE    => '0',
      G_NUM_GUARD_FFS => 3)
    port map (
      i_clk   => clk,
      i_data  => req_async,
      o_data  => req);

  rpi_colossus : entity work.RPi_Colossus
    port map (
      clk            => clk,
      data_addr_muxd => data_addr_muxd,
      data_addr_sel  => data_addr_sel,
      req            => req,
      busy           => busy,
      resp_err       => resp_err,
      resp           => resp);

end architecture behaviour;
