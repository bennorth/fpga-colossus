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

def letter_from_impulses(impulses):
    return (16 * impulses[0]
            + 8 * impulses[1]
            + 4 * impulses[2]
            + 2 * impulses[3]
            + 1 * impulses[4])

def impulse_stream_from_wheel(w, n):
    "Return an array of size N formed by cycling through the elements of W."
    n_repeats_needed = int(np.ceil(n / w.size))
    possibly_overlength_stream = np.tile(w, n_repeats_needed)
    return possibly_overlength_stream[:n]

def rot_wheel(w, n):
    """
    Return the result of rotating the given pattern W by N positions.
    The [0] element of the result is the [N] element of the input W.
    """
    return np.concatenate([w[n:], w[:n]])


class Chi:
    def __init__(self, chi, step_counts):
        "STEP_COUNTS --- list of values used as the wheels' settings."
        self.chi = [rot_wheel(w, n) for w, n in zip(chi, step_counts)]

    def letters(self, n_sprockets):
        impulses = [impulse_stream_from_wheel(w, n_sprockets) for w in self.chi]
        return letter_from_impulses(impulses)


class PsiAndMu:
    def __init__(self, psi, mu, step_counts):
        """
        STEP_COUNTS --- first five elements give Psi settings; remaining
        two elements give the Mu settings.
        """
        self.psi = [rot_wheel(w, n) for w, n in zip(psi, step_counts[:5])]
        self.mu = [rot_wheel(w, n) for w, n in zip(mu, step_counts[5:])]

    def letters(self, n_sprockets):
        mu_0_stream = impulse_stream_from_wheel(self.mu[0], n_sprockets - 1)
        unext_mu_1_stream = impulse_stream_from_wheel(self.mu[1], n_sprockets)
        mu_1_idxs = np.concatenate([[0], np.cumsum(mu_0_stream.astype(np.int32))])
        ext_mu_1_stream = unext_mu_1_stream[mu_1_idxs]

        impulses = [impulse_stream_from_wheel(w, n_sprockets) for w in self.psi]
        unext_psi_stream = letter_from_impulses(impulses)
        psi_idxs = np.concatenate([[0], np.cumsum(ext_mu_1_stream[:-1].astype(np.int32))])
        ext_psi_stream = unext_psi_stream[psi_idxs]

        return ext_psi_stream
