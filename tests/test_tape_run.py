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

from colossus import QPanelTopUnitCfg

TAPE_LENGTH = 40

@pytest.mark.parametrize('n_ones', [0, 1, 20, 39, 40])
@pytest.mark.parametrize('ones_location', ['start', 'end'])
@pytest.mark.parametrize('negate_p', [False, True])
def test_counting(colossus, n_ones, ones_location, negate_p):
    zs = np.zeros(TAPE_LENGTH, dtype=np.uint8)
    if ones_location == 'start':
        zs[:n_ones] = 31
    elif ones_location == 'end':
        first_one_idx = TAPE_LENGTH - n_ones
        zs[first_one_idx:] = 31
    colossus.punch_tape(zs)

    colossus.set_q_selector_cfg(0x20)
    colossus.reset_q_panel_cfg()
    colossus.set_q_panel_top_unit_cfg(
        0,
        QPanelTopUnitCfg(0x01, 0x01, 1 if negate_p else 0, 0x01))

    colossus.run_tape_once()
    colossus.snapshot_counters()

    got_counts = colossus.read_all_counters()
    exp_count = n_ones if not negate_p else (TAPE_LENGTH - n_ones)

    # (Note: Counter indexing is sub-optimal.)
    assert got_counts[4] == exp_count
    assert np.all(got_counts[:4] == TAPE_LENGTH)


@pytest.mark.parametrize(
    'cfg, exp_count',
    [(0x20, TAPE_LENGTH),
     (0x30, TAPE_LENGTH - 1),
     (0x28, TAPE_LENGTH),
     (0x2c, TAPE_LENGTH - 1),
     (0x22, TAPE_LENGTH),
     (0x23, TAPE_LENGTH - 1)],
    ids=['z', 'dz', 'z+chi', 'z+dchi', 'z+psi', 'z+dpsi'])
#
def test_counting_with_delta(colossus, cfg, exp_count):
    zs = np.zeros(TAPE_LENGTH, dtype=np.uint8)
    colossus.punch_tape(zs)
    colossus.set_q_selector_cfg(cfg)
    colossus.reset_q_panel_cfg()

    colossus.run_tape_once()
    colossus.snapshot_counters()

    got_counts = colossus.read_all_counters()
    assert np.all(got_counts == exp_count)
