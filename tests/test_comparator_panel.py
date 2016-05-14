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
from itertools import product, islice
from colossus import (QPanelTopUnitCfg,
                      SetTotalCfg, SetTotalOperation,
                      WorkerIndex, ColossusTesting)

TAPE_LENGTH = 80


def perform_cmp_1(op, x, y):
    if op == SetTotalOperation.Count_GT_Threshold:
        return int(x > y)
    elif op == SetTotalOperation.Count_LT_Threshold:
        return int(x < y)
    else:
        return 1

def perform_cmps(ops, xs, ys):
    v_cmp = [perform_cmp_1(op, x, y) for (op, x, y) in zip(ops, xs, ys)]
    # (Note: Ordering of bits is sub-optimal.)
    return sum(cmp * (2 ** i) for i, cmp in enumerate(v_cmp[::-1]))


def _test_comparison(colossus, ctrs, thrs, ops):
    for i, (thr, op) in enumerate(zip(thrs, ops)):
        colossus.set_set_total_config(i, SetTotalCfg(thr, op))

    exp_gt = perform_cmps([SetTotalOperation.Count_GT_Threshold]
                          * colossus.N_COUNTERS, ctrs, thrs)
    exp_lt = perform_cmps([SetTotalOperation.Count_LT_Threshold]
                          * colossus.N_COUNTERS, ctrs, thrs)
    exp_print_req = perform_cmps(ops, ctrs, thrs)

    assert colossus.read_counter_value_gt_threshold() == exp_gt
    assert colossus.read_counter_value_lt_threshold() == exp_lt
    assert colossus.read_print_required_vec() == exp_print_req
    assert colossus.read_print_required() == int(exp_print_req != 0)


def test_counting(colossus):
    exp_ctrs = ColossusTesting.establish_sample_counts(colossus)
    got_ctrs = colossus.read_all_counters()
    assert np.all(got_ctrs == exp_ctrs)

    colossus.scheduler_trigger_manual(WorkerIndex.Comparator_Copy_Counter_Values)
    comparator_ctrs = colossus.comparator_read_counter_values()
    assert np.all(comparator_ctrs == exp_ctrs)

    # If threshold are equal to the counter values, should only see
    # 'true' for 'print reqd' under 'always true'.
    #
    inequality_ops = [SetTotalOperation.Count_GT_Threshold,
                      SetTotalOperation.Count_LT_Threshold]
    for inequality_op in inequality_ops:
        ops = [inequality_op] * colossus.N_COUNTERS
        _test_comparison(colossus, got_ctrs, got_ctrs, ops)

    # Test sample of operator combinations with a mixture of
    # over/under-value thresholds.
    #
    over_under_thresholds = got_ctrs + np.array([-10, 10, 10, -10, -10])
    for op_idxs in islice(product(*([[0, 1, 2]] * colossus.N_COUNTERS)),
                          None, None, 4):
        ops = [SetTotalOperation(i) for i in op_idxs]
        _test_comparison(colossus, got_ctrs, over_under_thresholds, ops)

    # Test sample of over/under/equal-to thresholds with a mixture of
    # operator combinations.
    #
    ops = [SetTotalOperation(i) for i in [0, 1, 1, 0, 2]]
    for rel_thrs in islice(product(*([[-10, 0, 10]] * colossus.N_COUNTERS)),
                           None, None, 4):
        over_under_thresholds = got_ctrs + rel_thrs
        _test_comparison(colossus, got_ctrs, over_under_thresholds, ops)
