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

from colossus import QPanelTopUnitCfg, WorkerIndex, ColossusTesting


def test_counting(colossus):
    exp_ctrs = ColossusTesting.establish_sample_counts(colossus,
                                                       tape_length=TAPE_LENGTH,
                                                       run_method='loop_one_shot')
    got_ctrs = colossus.read_all_counters()
    assert np.all(got_ctrs == exp_ctrs)

    # Should still have previous values stored in the comparator.
    assert np.all(colossus.comparator_read_counter_values() == 0)

    # But on loading, they should match the counter-panel-snapshot.
    colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Counter_Values)
    comparator_ctrs = colossus.comparator_read_counter_values()
    assert np.all(comparator_ctrs == exp_ctrs)


def test_latch_counters_worker(colossus):
    exp_ctrs = ColossusTesting.establish_sample_counts(colossus)
    got_ctrs = colossus.read_all_counters()
    assert np.all(got_ctrs == exp_ctrs)

    colossus.reset_counters()
    got_ctrs = colossus.read_all_counters()
    assert np.all(got_ctrs == exp_ctrs)
    colossus.scheduler_trigger_manual(WorkerIndex.Counters_Latch_Values)
    got_ctrs = colossus.read_all_counters()
    assert np.all(got_ctrs == 0)
