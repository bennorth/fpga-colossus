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
from colossus import Colossus


class PsiAndMu:
    def __init__(self, psi, mu):
        if list(map(len, psi)) != Colossus.N_CAMS_PSI:
            raise ValueError('wrong psi lengths')
        if list(map(len, mu)) != Colossus.N_CAMS_MU:
            raise ValueError('wrong mu lengths')
        self.psi = psi
        self.mu = mu

    @property
    def psi_letter(self):
        # PSI_1, stored as psi[0], is the MOST-significant bit.
        return (16 * self.psi[0][0]
                + 8 * self.psi[1][0]
                + 4 * self.psi[2][0]
                + 2 * self.psi[3][0]
                + 1 * self.psi[4][0])

    def move(self):
        mu_61 = self.mu[0]
        mu_37 = self.mu[1]
        if mu_37[0]:
            self.psi = [w[1:] + w[:1] for w in self.psi]
        if mu_61[0]:
            self.mu[1] = mu_37[1:] + mu_37[:1]
        self.mu[0] = mu_61[1:] + mu_61[:1]

    def psi_letter_then_move(self):
        psi = self.psi_letter
        self.move()
        return psi

    @classmethod
    def extend_psi(cls, psi, mu, n_sprockets):
        psi_and_mu = cls(psi, mu)
        return np.array(
                   [psi_and_mu.psi_letter_then_move() for _ in range(n_sprockets)],
                   dtype=np.uint8)


def test_psi_extension(colossus):
    np.random.seed(42)
    psi = [list(np.random.randint(2, size=n)) for n in Colossus.N_CAMS_PSI]
    mu = [list(np.random.randint(2, size=n)) for n in Colossus.N_CAMS_MU]

    for i, p in enumerate(psi):
        colossus.load_psi_wheel_pattern(i, p)
    for i, p in enumerate(mu):
        colossus.load_mu_wheel_pattern(i, p)

    colossus.reset_all_stepping()
    colossus.set_q_selector_cfg(int('000010', 2))

    n_letters = 120
    q = colossus.snoop_Q_vec(n_letters)
    exp_extended_psi = PsiAndMu.extend_psi(psi, mu, n_letters)

    assert np.all(q == exp_extended_psi)
