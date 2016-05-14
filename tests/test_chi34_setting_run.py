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

import pytest
import wheels
import wheel_patterns
import numpy as np
import pickle
from operator import itemgetter as nth
from sample_long_run import chi34_results, set_total_threshold


slow = pytest.mark.skipif(
    not pytest.config.getoption("--runslow"),
    reason="need --runslow option to run"
)


def delta_stream(x):
    return x[1:] ^ x[:-1]


@pytest.fixture
def exp_results():
    with open('sample_PP_Z.pkl', 'rb') as f_in:
        specimen_ciphertext = pickle.load(f_in)
    tape_length = specimen_ciphertext.size

    records = []
    # Iterate over chi4 in the outer loop as that is 'slow' stepping
    # in the test below.
    for chi4 in range(wheel_patterns.chi[3].size):
        for chi3 in range(wheel_patterns.chi[2].size):
            candidate_chi_wheels = wheels.Chi(wheel_patterns.chi, [0, 0, chi3, chi4, 0])
            candidate_chi_letters = candidate_chi_wheels.letters(tape_length)
            candidate_de_chi = specimen_ciphertext ^ candidate_chi_letters

            impulse_3 = np.minimum(1, candidate_de_chi & 4)
            impulse_4 = np.minimum(1, candidate_de_chi & 2)
            dot3p4 = np.sum(delta_stream(impulse_3 ^ impulse_4) == 0)

            records.append((chi3, chi4, dot3p4))

    return [r for r in records if r[2] < set_total_threshold]


@slow
@pytest.mark.parametrize('both_fast_p', [False, True], ids=['fast-slow', 'both-fast'])
def test_chi34_run(colossus, both_fast_p, exp_results):
    raw_results = chi34_results(colossus, both_fast_p)

    got_results = (sorted(raw_results, key=nth(1, 0)) if both_fast_p
                   else raw_results)

    assert got_results == exp_results
