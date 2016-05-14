# Copyright 2016 Ben North; some portions Crown Copyright where noted
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

# Transcribed from image appearing in General Report on Tunny [p.21];
# this transcription of Crown Copyright material permitted under Open
# Government Licence:
#
# http://www.nationalarchives.gov.uk/doc/open-government-licence/version/2/
#
# Ultimate source: The National Archive document HW25/4.
#
specimen_patterns_raw = [
    '0+0+0 0+0++ 0+0+0 +0+00 ++000 ++++0 0+0+0 +0++0 ++0',
    '00+0+ 0++0+ 0+++0 0++0+ 0+00+ +0000 +0+0+ ++00+ 0++0+ 0+',
    '0+00+ ++000 +0+00 0++00 +0+0+ +0+0+ ++00+ 0+00+ 0+0++ +0+0+ +',
    '+0++0 0++0+ 00+0+ 0+00+ +0000 +++00 +0+++ +0+0+ 0+0+0 +00+0 ++0',
    '+0+00 +0+0+ 0+00+ 000++ 000+0 +++0+ +0+0+ 0+00+ ++00+ 0+++0 0+0++ 0+0+',
    '++000 +0++0 ++++0 +++00 ++000 +0+0+ 000++ +0',
    '+0+00 00+++ 00+++ +0+++ +00++ ++0++ ++0++ ++000 ++++0 +++0+ ++00+ +++0+ +',
    '0++00 ++00+ +00++ 00++0 0++++ 00++0 0+00+ +00++ 0',
    '000+0 +00+0 ++000 0+++0 0+0++ ++0++ 0',
    '+++00 +++00 +++00 +0000 +++0+ 00+0',
    '00+0+ +++00 +00++ 0000+ +++00 +',
    '++000 +++0+ 00+++ 0+000 ++0']

specimen_patterns = [p.replace(' ', '').replace('+', '1')
                     for p in specimen_patterns_raw]

specimen_chi_chars = [specimen_patterns[i] for i in [7, 8, 9, 10, 11]]
specimen_psi_chars = [specimen_patterns[i] for i in [0, 1, 2, 3, 4]]
specimen_mu_chars = [specimen_patterns[i] for i in [6, 5]]

def mk_arrays(strs):
    return [np.array([int(c) for c in s], dtype=np.uint8)
            for s in strs]

chi = mk_arrays(specimen_chi_chars)
psi = mk_arrays(specimen_psi_chars)
mu = mk_arrays(specimen_mu_chars)

_exp_chi_lengths = [41, 31, 29, 26, 23]
_exp_psi_lengths = [43, 47, 51, 53, 59]
_exp_mu_lengths = [61, 37]

assert np.all(list(map(len, chi)) == _exp_chi_lengths)
assert np.all(list(map(len, psi)) == _exp_psi_lengths)
assert np.all(list(map(len, mu)) == _exp_mu_lengths)
