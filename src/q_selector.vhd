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

entity Q_Selector is

  port (
    clk    : in  std_logic;
    ctrl_i : in  Q_Selector_Ctrl_t;
    -- stream inputs:
    z_i    : in  TP_Letter_t;
    chi_i  : in  TP_Letter_t;
    psi_i  : in  TP_Letter_t;
    -- configuration input:
    cfg_i  : in  Q_Selector_Cfg_t;
    -- output:
    q_delta_o : out std_logic;
    q_o    : out TP_Letter_t);

end Q_Selector;

architecture behaviour of Q_Selector is

  signal z_one_back       : TP_Letter_t := TP_LETTER_ZERO;
  signal chi_one_back     : TP_Letter_t := TP_LETTER_ZERO;
  signal psi_one_back     : TP_Letter_t := TP_LETTER_ZERO;

  function contribution_1(stream    : TP_Letter_t;
                          stream_1b : TP_Letter_t;
                          en        : std_logic;
                          delta     : std_logic)
    return TP_Letter_t
  is
  begin
    if en = '0' then
      return TP_LETTER_ZERO;
    elsif delta = '0' then
      return stream;
    else
      return (stream xor stream_1b);
    end if;
  end function;

begin

  calculate_Q : process (clk)
  is
    variable z_contrib, chi_contrib, psi_contrib : TP_Letter_t;
  begin
    if rising_edge(clk) then
      if ctrl_i.rst = '1' then
        z_one_back <= TP_LETTER_ZERO;
        chi_one_back <= TP_LETTER_ZERO;
        psi_one_back <= TP_LETTER_ZERO;
        q_o <= TP_LETTER_ZERO;
      elsif ctrl_i.en = '1' then
        z_contrib   := contribution_1(z_i, z_one_back,
                                      cfg_i.z_en, cfg_i.z_delta);
        chi_contrib := contribution_1(chi_i, chi_one_back,
                                      cfg_i.chi_en, cfg_i.chi_delta);
        psi_contrib := contribution_1(psi_i, psi_one_back,
                                      cfg_i.psi_en, cfg_i.psi_delta);

        q_o <= z_contrib xor chi_contrib xor psi_contrib;

        z_one_back   <= z_i;
        chi_one_back <= chi_i;
        psi_one_back <= psi_i;
      end if;
    end if;
  end process;

  q_delta_o <= ((cfg_i.z_en and cfg_i.z_delta)
                or (cfg_i.chi_en and cfg_i.chi_delta)
                or (cfg_i.psi_en and cfg_i.psi_delta));

end architecture;
