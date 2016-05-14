# Copyright 2016 Ben North
#
# This file is part of "FPGA Colossus".
#
# "FPGA Colossus" is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option) any
# later version.
#
# "FPGA Colossus" is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# "FPGA Colossus".  If not, see <http://www.gnu.org/licenses/>.

import numpy as np
import pytest

TAPE_LENGTH = 320

from colossus import (QPanelTopUnitCfg, QPanelBottomUnitCfg, QPanelNegatingCfg,
                      ColossusTesting)


def test_summands(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH)
    colossus.reset_q_panel_cfg()
    colossus.set_q_panel_top_unit_cfg(0, QPanelTopUnitCfg(0x01, 0x01, 0x00, 0x05))
    colossus.set_q_selector_cfg(0x20)
    a_vec = colossus.snoop_A_vec(TAPE_LENGTH)
    exp_a_vec = np.where((zs & 0x01) == 0x01, 0x1f, 0x1a)
    assert np.all(a_vec == exp_a_vec)

def test_summands_1(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH)
    colossus.reset_q_panel_cfg()
    colossus.set_q_panel_top_unit_cfg(0, QPanelTopUnitCfg(0x01, 0x01, 0x00, 0x05))
    colossus.set_q_panel_top_unit_cfg(1, QPanelTopUnitCfg(0x02, 0x02, 0x00, 0x03))
    colossus.set_q_selector_cfg(0x20)
    a_vec = colossus.snoop_A_vec(TAPE_LENGTH)
    exp_a_vec = (np.where((zs & 0x01) == 0x01, 0x1f, 0x1a)
                 & np.where((zs & 0x02) == 0x02, 0x1f, 0x1c))
    assert np.all(a_vec == exp_a_vec)

def test_summands_btm(colossus):
    zs = colossus.punch_random_tape(TAPE_LENGTH)
    colossus.reset_q_panel_cfg()
    colossus.set_q_panel_bottom_unit_cfg(0, QPanelBottomUnitCfg(0x02, 0x00, 0x01))
    colossus.set_q_panel_bottom_unit_cfg(1, QPanelBottomUnitCfg(0x03, 0x00, 0x02))
    colossus.set_q_panel_bottom_unit_cfg(2, QPanelBottomUnitCfg(0x05, 0x01, 0x04))
    colossus.set_q_panel_bottom_unit_cfg(3, QPanelBottomUnitCfg(0x10, 0x01, 0x03))
    colossus.set_q_selector_cfg(0x20) # un-delta'd Z
    a_vec = colossus.snoop_A_vec(TAPE_LENGTH)

    par = ColossusTesting.parity

    b0s = [par[z & 0x02] == 0 for z in zs]
    b1s = [par[z & 0x03] == 0 for z in zs]
    b2s = [par[z & 0x05] == 1 for z in zs]
    b3s = [par[z & 0x10] == 1 for z in zs]

    exp_a_vec = [(0x1f if b0 else 0x1e)
                 & (0x1f if b1 else 0x1d)
                 & (0x1f if b2 else 0x1b)
                 & (0x1f if b3 else 0x1c)
                 for b0, b1, b2, b3 in zip(b0s, b1s, b2s, b3s)]

    assert np.all(a_vec == exp_a_vec)

@pytest.mark.parametrize('global_negate', [False, True])
@pytest.mark.parametrize('seed', [42, 100, 234])
def test_summands_global_negations(colossus, seed, global_negate):
    zs = colossus.punch_random_tape(TAPE_LENGTH, seed=seed)
    colossus.reset_q_panel_cfg()

    # Replicate example at top of p.325 in GRT book.
    colossus.set_q_panel_top_unit_cfg(
        0, QPanelTopUnitCfg.from_string('101-- == 10000'))
    colossus.set_q_panel_top_unit_cfg(
        1, QPanelTopUnitCfg.from_string('11-1- != 01000'))
    colossus.set_q_panel_top_unit_cfg(
        2, QPanelTopUnitCfg.from_string('00-0- != 01000'))
    colossus.set_q_panel_bottom_unit_cfg(
        0, QPanelBottomUnitCfg.from_string('11--- 0 00100'))
    colossus.set_q_panel_bottom_unit_cfg(
        1, QPanelBottomUnitCfg.from_string('1---1 0 00100'))
    colossus.set_q_panel_negating_cfg(
        QPanelNegatingCfg(0x08, 0x1f if global_negate else 0x00))
    colossus.set_q_selector_cfg(0x20) # un-delta'd Z
    a_vec = colossus.snoop_A_vec(TAPE_LENGTH)

    # Insert dummy 'None' at front to fake 1-based indexing.
    zi = [None] + [np.minimum(1, zs & impulse_val)
                   for impulse_val in [16, 8, 4, 2, 1]]

    got_a = np.array([np.minimum(1, a_vec & impulse_val)
                      for impulse_val in [16, 8, 4, 2, 1]])

    # Counters should have got:
    exp_a = np.array([
        (zi[1] == 1) & (zi[2] == 0) & (zi[3] == 1),  # 1x2.3x
        (zi[1] == zi[2]) & (zi[1] == zi[4]),         # 1=2=4
        (zi[1] == zi[2]) & (zi[1] == zi[5]),         # 1=2=5
        np.ones_like(zs),
        np.ones_like(zs)]) ^ global_negate

    assert np.all(got_a == exp_a)
