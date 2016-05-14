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

from colossus import (SetTotalOperation, SetTotalCfg,
                      SteppingCfg, QPanelTopUnitCfg,
                      WorkerIndex, PrintRecord, ColossusTesting)

step_fast_cfg = SteppingCfg(True, False, False, False)

# (Note: 0x10 means 'counter 0'; bit-ordering is sub-optimal.)
count_impulse_1_cross = QPanelTopUnitCfg(0x10, 0x10, False, 0x10)


def test_short_run(colossus):
    tape_len = 164
    zs = colossus.punch_random_tape(tape_len)
    chi_1 = [1] + [0] * 40
    colossus.load_chi_wheel_pattern(0, chi_1)
    colossus.reset_q_panel_cfg()
    colossus.set_q_panel_top_unit_cfg(0, count_impulse_1_cross)
    colossus.set_q_selector_cfg(int('101000', 2)) # Z + CHI
    colossus.set_set_total_config(0, SetTotalCfg.AlwaysPrint)
    colossus.reset_all_step_count_vector_configs()
    colossus.set_step_count_vector_config(0, step_fast_cfg)

    colossus.printer_reset()
    colossus.initiate_run()

    print_records = colossus.printer_read_records()

    assert len(print_records) == 41
    assert np.all([r.stepping_settings[0] for r in print_records] == np.arange(41))
    assert np.all(np.array([r.stepping_settings[1:] for r in print_records]) == 0)
    assert np.all(np.array([r.counters[1:] for r in print_records]) == tape_len)

    body_ids = np.array([r.body_id for r in print_records])
    assert np.sum(body_ids == 0) == 20
    assert np.sum(body_ids == 1) == 21

    got_ctr_0s = np.array([r.counters[0] for r in print_records])
    exp_ctr_0s = np.array([expected_count(zs, chi_1, i) for i in range(41)])
    assert np.all(got_ctr_0s == exp_ctr_0s)


def expected_count(zs, chi_1, stepping):
    assert len(zs) % len(chi_1) == 0
    effective_chi = chi_1[stepping:] + chi_1[:stepping]

    # '* 16' to turn into 'Impulse 1' value:
    full_chi = np.array(effective_chi * (len(zs) // len(chi_1)), dtype=np.uint8) * 16

    q = zs ^ full_chi
    q1 = np.where(q & 16, 1, 0)
    return np.sum(q1)
