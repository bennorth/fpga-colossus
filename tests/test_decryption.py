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

import wheels
import wheel_patterns

tape_length = 200


def test_decryption(colossus):
    # Arbitrary:
    stepping_settings = [2, 5, 10, 10, 7]
    chi_wheels = wheels.Chi(wheel_patterns.chi, stepping_settings)
    psi_mu_wheels = wheels.PsiAndMu(wheel_patterns.psi, wheel_patterns.mu,
                                    [0, 0, 0, 0, 0, 0, 0])

    chi_stream = chi_wheels.letters(tape_length)
    psi_stream = psi_mu_wheels.letters(tape_length)
    key = chi_stream ^ psi_stream

    plain = np.random.randint(32, size=tape_length).astype(np.uint8)
    cipher = key ^ plain
    colossus.punch_tape(cipher)

    for i, chi in enumerate(wheel_patterns.chi):
        colossus.load_chi_wheel_pattern(i, chi)
    for i, psi in enumerate(wheel_patterns.psi):
        colossus.load_psi_wheel_pattern(i, psi)
    for i, mu in enumerate(wheel_patterns.mu):
        colossus.load_mu_wheel_pattern(i, mu)

    colossus.reset_all_stepping()
    for i, stepping_setting in enumerate(stepping_settings):
        colossus.set_cam_wheel_stepping(i, stepping_setting)

    # Q = Z + CHI + PSI, i.e., Q = plain.
    colossus.set_q_selector_cfg(int('101010', 2))

    got_plain = colossus.snoop_Q_vec(tape_length)
    assert np.all(got_plain == plain)
