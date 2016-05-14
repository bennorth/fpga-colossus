// Copyright 2016 Ben North
//
// This file is part of "FPGA Colossus".
//
// "FPGA Colossus" is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option) any
// later version.
//
// "FPGA Colossus" is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
// FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
// more details.
//
// You should have received a copy of the GNU General Public License along with
// "FPGA Colossus".  If not, see <http://www.gnu.org/licenses/>.

$(document).ready(function() {

    // Events data captured from simulation.
    //
    // 'gn' = 'generate'
    // 'd' = 'distribute' (mapped in code to 'd0' or 'd1')
    // 'p' = 'print' (mapped in code to 'p0' or 'p1')
    // 'sa0' = 'b0_settings_active'
    // 'sa1' = 'b1_settings_active'
    // 'sl0' = 'b0_settings_labels'
    // 'sl1' = 'b1_settings_labels'
    // 'al0' = 'b0_active_live'
    // 'al1' = 'b1_active_live'
    // 'll0' = 'b0_live_latched'
    // 'll1' = 'b1_live_latched'
    // 'lc0' = 'b0_latched_comparands'
    // 'lc1' = 'b1_latched_comparands'
    //
    var Events
        = [[0, ["gn"]], [5, ["gn"]], [9, ["d"]], [33, ["d"]], [34, ["gn"]], [39,
           ["gn"]], [42, ["sa1"]], [43, ["sl1"]], [44, ["d"]], [46, ["sa1"]], [52,
           ["al1"]], [57, ["sl1"]], [68, ["d"]], [69, ["gn"]], [74, ["gn"]], [77,
           ["sa0"]], [78, ["d", "sl0"]], [81, ["sa0"]], [87, ["al0"]], [92,
           ["sl0"]], [102, ["d"]], [103, ["gn"]], [108, ["gn"]], [113, ["d"]],
           [137, ["d"]], [138, ["gn"]], [143, ["gn"]], [348, ["al1"]], [350,
           ["sa1"]], [354, ["ll1", "sa1"]], [361, ["ll1"]], [363, ["al1"]], [367,
           ["lc1"]], [374, ["lc1"]], [383, ["al0"]], [385, ["p", "sa0"]], [389,
           ["ll0", "sa0"]], [396, ["ll0"]], [398, ["al0"]], [402, ["lc0"]], [409,
           ["lc0"]], [416, ["p"]], [420, ["sl1"]], [421, ["p"]], [434, ["sl1"]],
           [437, ["d"]], [452, ["p"]], [456, ["sl0"]], [461, ["d"]], [462, ["gn"]],
           [467, ["gn"]], [470, ["sl0"]], [472, ["d"]], [496, ["d"]], [497,
           ["gn"]], [502, ["gn"]], [659, ["al1"]], [661, ["sa1"]], [665, ["ll1",
           "sa1"]], [672, ["ll1"]], [674, ["al1"]], [678, ["lc1"]], [685, ["lc1"]],
           [694, ["al0"]], [696, ["sa0"]], [697, ["p"]], [700, ["ll0", "sa0"]],
           [707, ["ll0"]], [709, ["al0"]], [713, ["lc0"]], [720, ["lc0"]], [728,
           ["p"]], [731, ["p"]], [732, ["sl1"]], [746, ["sl1"]], [748, ["d"]],
           [762, ["p"]], [766, ["sl0"]], [772, ["d"]], [773, ["gn"]], [778,
           ["gn"]], [780, ["sl0"]], [783, ["d"]], [807, ["d"]], [808, ["gn"]],
           [813, ["gn"]], [970, ["al1"]], [972, ["sa1"]], [976, ["ll1", "sa1"]],
           [983, ["ll1"]], [985, ["al1"]], [989, ["lc1"]], [996, ["lc1"]], [1005,
           ["al0"]], [1007, ["p", "sa0"]], [1011, ["ll0", "sa0"]], [1018, ["ll0"]],
           [1020, ["al0"]], [1024, ["lc0"]], [1031, ["lc0"]], [1038, ["p"]], [1042,
           ["sl1"]], [1043, ["p"]], [1056, ["sl1"]], [1059, ["d"]], [1074, ["p"]],
           [1078, ["sl0"]], [1083, ["d"]], [1084, ["gn"]], [1089, ["gn"]], [1092,
           ["sl0"]], [1094, ["d"]], [1118, ["d"]], [1119, ["gn"]], [1124, ["gn"]],
           [1281, ["al1"]], [1283, ["sa1"]], [1287, ["ll1", "sa1"]], [1294,
           ["ll1"]], [1296, ["al1"]], [1300, ["lc1"]], [1307, ["lc1"]], [1316,
           ["al0"]], [1318, ["sa0"]], [1319, ["p"]], [1322, ["ll0", "sa0"]], [1329,
           ["ll0"]], [1331, ["al0"]], [1335, ["lc0"]], [1342, ["lc0"]], [1350,
           ["p"]], [1353, ["p"]], [1354, ["sl1"]], [1368, ["sl1"]], [1370, ["d"]],
           [1384, ["p"]], [1388, ["sl0"]], [1394, ["d"]], [1395, ["gn"]], [1400,
           ["gn"]], [1402, ["sl0"]], [1405, ["d"]], [1429, ["d"]], [1430, ["gn"]],
           [1435, ["gn"]], [1592, ["al1"]], [1594, ["sa1"]], [1598, ["ll1",
           "sa1"]], [1605, ["ll1"]], [1607, ["al1"]], [1611, ["lc1"]], [1618,
           ["lc1"]], [1627, ["al0"]], [1629, ["p", "sa0"]], [1633, ["ll0", "sa0"]],
           [1640, ["ll0"]], [1642, ["al0"]], [1646, ["lc0"]], [1653, ["lc0"]],
           [1660, ["p"]], [1664, ["sl1"]], [1665, ["p"]], [1678, ["sl1"]], [1681,
           ["d"]], [1696, ["p"]], [1700, ["sl0"]], [1705, ["d"]], [1706, ["gn"]],
           [1711, ["gn"]], [1714, ["sl0"]], [1716, ["d"]], [1740, ["d"]], [1741,
           ["gn"]], [1746, ["gn"]], [1903, ["al1"]], [1905, ["sa1"]], [1909,
           ["ll1", "sa1"]], [1916, ["ll1"]], [1918, ["al1"]], [1922, ["lc1"]],
           [1929, ["lc1"]], [1938, ["al0"]], [1940, ["sa0"]], [1941, ["p"]], [1944,
           ["ll0", "sa0"]], [1951, ["ll0"]], [1953, ["al0"]], [1957, ["lc0"]],
           [1964, ["lc0"]], [1972, ["p"]], [1975, ["p"]], [1976, ["sl1"]], [1990,
           ["sl1"]], [1992, ["d"]], [2006, ["p"]], [2010, ["sl0"]], [2016, ["d"]],
           [2017, ["gn"]], [2022, ["gn"]], [2024, ["sl0"]], [2027, ["d"]], [2051,
           ["d"]], [2052, ["gn"]], [2057, ["gn"]], [2214, ["al1"]], [2216,
           ["sa1"]], [2220, ["ll1", "sa1"]], [2227, ["ll1"]], [2229, ["al1"]],
           [2233, ["lc1"]], [2240, ["lc1"]], [2249, ["al0"]], [2251, ["p", "sa0"]],
           [2255, ["ll0", "sa0"]], [2262, ["ll0"]], [2264, ["al0"]], [2268,
           ["lc0"]], [2275, ["lc0"]], [2282, ["p"]], [2286, ["sl1"]], [2287,
           ["p"]], [2300, ["sl1"]], [2303, ["d"]], [2318, ["p"]], [2322, ["sl0"]],
           [2327, ["d"]], [2328, ["gn"]], [2333, ["gn"]], [2336, ["sl0"]], [2338,
           ["d"]], [2362, ["d"]], [2363, ["gn"]], [2368, ["gn"]], [2525, ["al1"]],
           [2527, ["sa1"]], [2531, ["ll1", "sa1"]], [2538, ["ll1"]], [2540,
           ["al1"]], [2544, ["lc1"]], [2551, ["lc1"]], [2560, ["al0"]], [2562,
           ["sa0"]], [2563, ["p"]], [2566, ["ll0", "sa0"]], [2573, ["ll0"]], [2575,
           ["al0"]], [2579, ["lc0"]], [2586, ["lc0"]], [2594, ["p"]], [2597,
           ["p"]], [2598, ["sl1"]], [2612, ["sl1"]], [2614, ["d"]], [2628, ["p"]],
           [2632, ["sl0"]], [2638, ["d"]], [2639, ["gn"]], [2644, ["gn"]], [2646,
           ["sl0"]], [2649, ["d"]], [2673, ["d"]], [2674, ["gn"]], [2679, ["gn"]],
           [2836, ["al1"]], [2838, ["sa1"]], [2842, ["ll1", "sa1"]], [2849,
           ["ll1"]], [2851, ["al1"]], [2855, ["lc1"]], [2862, ["lc1"]], [2871,
           ["al0"]], [2873, ["p", "sa0"]], [2877, ["ll0", "sa0"]], [2884, ["ll0"]],
           [2886, ["al0"]], [2890, ["lc0"]], [2897, ["lc0"]], [2904, ["p"]], [2908,
           ["sl1"]], [2909, ["p"]], [2922, ["sl1"]], [2925, ["d"]], [2940, ["p"]],
           [2944, ["sl0"]], [2949, ["d"]], [2950, ["gn"]], [2955, ["gn"]], [2958,
           ["sl0"]], [2960, ["d"]], [2984, ["d"]], [2985, ["gn"]], [2990, ["gn"]],
           [3147, ["al1"]], [3149, ["sa1"]], [3153, ["ll1", "sa1"]], [3160,
           ["ll1"]], [3162, ["al1"]], [3166, ["lc1"]], [3173, ["lc1"]], [3182,
           ["al0"]], [3184, ["sa0"]], [3185, ["p"]], [3188, ["ll0", "sa0"]], [3195,
           ["ll0"]], [3197, ["al0"]], [3201, ["lc0"]], [3208, ["lc0"]], [3216,
           ["p"]], [3219, ["p"]], [3220, ["sl1"]], [3234, ["sl1"]], [3236, ["d"]],
           [3250, ["p"]], [3254, ["sl0"]], [3260, ["d"]], [3261, ["gn"]], [3266,
           ["gn"]], [3268, ["sl0"]], [3271, ["d"]], [3295, ["d"]], [3296, ["gn"]],
           [3301, ["gn"]], [3458, ["al1"]], [3460, ["sa1"]], [3464, ["ll1",
           "sa1"]], [3471, ["ll1"]], [3473, ["al1"]], [3477, ["lc1"]], [3484,
           ["lc1"]], [3493, ["al0"]], [3495, ["p", "sa0"]], [3499, ["ll0", "sa0"]],
           [3506, ["ll0"]], [3508, ["al0"]], [3512, ["lc0"]], [3519, ["lc0"]],
           [3526, ["p"]], [3530, ["sl1"]], [3531, ["p"]], [3544, ["sl1"]], [3547,
           ["d"]], [3562, ["p"]], [3566, ["sl0"]], [3571, ["d"]], [3572, ["gn"]],
           [3577, ["gn"]], [3580, ["sl0"]], [3582, ["d"]], [3606, ["d"]], [3607,
           ["gn"]], [3612, ["gn"]], [3769, ["al1"]], [3771, ["sa1"]], [3775,
           ["ll1", "sa1"]], [3782, ["ll1"]], [3784, ["al1"]], [3788, ["lc1"]],
           [3795, ["lc1"]], [3804, ["al0"]], [3806, ["sa0"]], [3807, ["p"]], [3810,
           ["ll0", "sa0"]], [3817, ["ll0"]], [3819, ["al0"]], [3823, ["lc0"]],
           [3830, ["lc0"]], [3838, ["p"]], [3841, ["p"]], [3842, ["sl1"]], [3856,
           ["sl1"]], [3858, ["d"]], [3872, ["p"]], [3876, ["sl0"]], [3882, ["d"]],
           [3883, ["gn"]], [3888, ["gn"]], [3890, ["sl0"]], [3893, ["d"]], [3917,
           ["d"]], [3918, ["gn"]], [3923, ["gn"]], [4080, ["al1"]], [4082,
           ["sa1"]], [4086, ["ll1", "sa1"]], [4093, ["ll1"]], [4095, ["al1"]],
           [4099, ["lc1"]], [4106, ["lc1"]], [4115, ["al0"]], [4117, ["p", "sa0"]],
           [4121, ["ll0", "sa0"]], [4128, ["ll0"]], [4130, ["al0"]], [4134,
           ["lc0"]], [4141, ["lc0"]], [4148, ["p"]], [4152, ["sl1"]], [4153,
           ["p"]], [4166, ["sl1"]], [4169, ["d"]], [4184, ["p"]], [4188, ["sl0"]],
           [4193, ["d"]], [4194, ["gn"]], [4199, ["gn"]], [4202, ["sl0"]], [4204,
           ["d"]], [4228, ["d"]], [4229, ["gn"]], [4234, ["gn"]], [4391, ["al1"]],
           [4393, ["sa1"]], [4397, ["ll1", "sa1"]], [4404, ["ll1"]], [4406,
           ["al1"]], [4410, ["lc1"]], [4417, ["lc1"]], [4426, ["al0"]], [4428,
           ["sa0"]], [4429, ["p"]], [4432, ["ll0", "sa0"]], [4439, ["ll0"]], [4441,
           ["al0"]], [4445, ["lc0"]], [4452, ["lc0"]], [4460, ["p"]], [4463,
           ["p"]], [4464, ["sl1"]], [4478, ["sl1"]], [4480, ["d"]], [4494, ["p"]],
           [4498, ["sl0"]], [4504, ["d"]], [4505, ["gn"]], [4510, ["gn"]], [4512,
           ["sl0"]], [4515, ["d"]], [4539, ["d"]], [4540, ["gn"]], [4545, ["gn"]],
           [4702, ["al1"]], [4704, ["sa1"]], [4708, ["ll1", "sa1"]], [4715,
           ["ll1"]], [4717, ["al1"]], [4721, ["lc1"]], [4728, ["lc1"]], [4737,
           ["al0"]], [4739, ["p", "sa0"]], [4743, ["ll0", "sa0"]], [4750, ["ll0"]],
           [4752, ["al0"]], [4756, ["lc0"]], [4763, ["lc0"]], [4770, ["p"]], [4774,
           ["sl1"]], [4775, ["p"]], [4788, ["sl1"]], [4791, ["d"]], [4806, ["p"]],
           [4810, ["sl0"]], [4815, ["d"]], [4816, ["gn"]], [4821, ["gn"]], [4824,
           ["sl0"]], [4826, ["d"]], [4850, ["d"]], [4851, ["gn"]], [4856, ["gn"]],
           [5013, ["al1"]], [5015, ["sa1"]], [5019, ["ll1", "sa1"]], [5026,
           ["ll1"]], [5028, ["al1"]], [5032, ["lc1"]], [5039, ["lc1"]], [5048,
           ["al0"]], [5050, ["sa0"]], [5051, ["p"]], [5054, ["ll0", "sa0"]], [5061,
           ["ll0"]], [5063, ["al0"]], [5067, ["lc0"]], [5074, ["lc0"]], [5082,
           ["p"]], [5085, ["p"]], [5086, ["sl1"]], [5100, ["sl1"]], [5102, ["d"]],
           [5116, ["p"]], [5120, ["sl0"]], [5126, ["d"]], [5127, ["gn"]], [5132,
           ["gn"]], [5134, ["sl0"]], [5137, ["d"]], [5161, ["d"]], [5162, ["gn"]],
           [5167, ["gn"]], [5324, ["al1"]], [5326, ["sa1"]], [5330, ["ll1",
           "sa1"]], [5337, ["ll1"]], [5339, ["al1"]], [5343, ["lc1"]], [5350,
           ["lc1"]], [5359, ["al0"]], [5361, ["p", "sa0"]], [5365, ["ll0", "sa0"]],
           [5372, ["ll0"]], [5374, ["al0"]], [5378, ["lc0"]], [5385, ["lc0"]],
           [5392, ["p"]], [5396, ["sl1"]], [5397, ["p"]], [5410, ["sl1"]], [5413,
           ["d"]], [5428, ["p"]], [5432, ["sl0"]], [5437, ["d"]], [5438, ["gn"]],
           [5443, ["gn"]], [5446, ["sl0"]], [5448, ["d"]], [5472, ["d"]], [5473,
           ["gn"]], [5478, ["gn"]], [5635, ["al1"]], [5637, ["sa1"]], [5641,
           ["ll1", "sa1"]], [5648, ["ll1"]], [5650, ["al1"]], [5654, ["lc1"]],
           [5661, ["lc1"]], [5670, ["al0"]], [5672, ["sa0"]], [5673, ["p"]], [5676,
           ["ll0", "sa0"]], [5683, ["ll0"]], [5685, ["al0"]], [5689, ["lc0"]],
           [5696, ["lc0"]], [5704, ["p"]], [5707, ["p"]], [5708, ["sl1"]], [5722,
           ["sl1"]], [5724, ["d"]], [5738, ["p"]], [5742, ["sl0"]], [5748, ["d"]],
           [5749, ["gn"]], [5754, ["gn"]], [5756, ["sl0"]], [5759, ["d"]], [5783,
           ["d"]], [5784, ["gn"]], [5789, ["gn"]], [5946, ["al1"]], [5948,
           ["sa1"]], [5952, ["ll1", "sa1"]], [5959, ["ll1"]], [5961, ["al1"]],
           [5965, ["lc1"]], [5972, ["lc1"]], [5981, ["al0"]], [5983, ["p", "sa0"]],
           [5987, ["ll0", "sa0"]], [5994, ["ll0"]], [5996, ["al0"]], [6000,
           ["lc0"]], [6007, ["lc0"]], [6014, ["p"]], [6018, ["sl1"]], [6019,
           ["p"]], [6032, ["sl1"]], [6035, ["d"]], [6050, ["p"]], [6054, ["sl0"]],
           [6059, ["d"]], [6068, ["sl0"]], [6257, ["al1"]], [6259, ["sa1"]], [6263,
           ["ll1", "sa1"]], [6270, ["ll1"]], [6272, ["al1"]], [6276, ["lc1"]],
           [6283, ["lc1"]], [6292, ["al0"]], [6295, ["p"]], [6298, ["ll0"]], [6305,
           ["ll0"]], [6311, ["lc0"]], [6318, ["lc0"]], [6326, ["p"]], [6329,
           ["p"]], [6330, ["sl1"]], [6344, ["sl1"]], [6360, ["p"]], [6568,
           ["al1"]], [6574, ["ll1"]], [6581, ["ll1"]], [6587, ["lc1"]], [6594,
           ["lc1"]], [6605, ["p"]], [6636, ["p"]]];

    var draw = SVG('twin-body-animation').size(600, 660);
    var dgrp = draw.group().scale(0.75);

    var Datum_Colours = ['#eee', // datum == 0 is 'not busy'
                         '#ff4040', '#40ff40', '#6060ff',
                         '#30e0e0', '#ff40ff'];

    var Datum_Half_Colours = ['#eee', // datum == 0 is 'not busy'
                              '#ffa0a0', '#a0ffa0', '#b0b0ff',
                              '#80f0f0', '#ffa0ff'];

    var text_spec = {
        family: 'helvetica,arial',
        size: 14,
        anchor: 'middle',
        leading: 1,
    };

    var text_spec_i = jQuery.extend({style: 'italic'}, text_spec);

    var stroke_spec = {color: '#000', width: 1.2};

    var x0 = 20, y0 = 10;
    var x_scale = 10, y_scale = 100;

    var proc_rect_wd = 110;
    var prog_bar_wd = 80;

    ////////////////////////////////////////////////////////////////////////

    var all_progress_bars = [];

    function ProgressBar(proc) {
        this.proc = proc;

        var pb_x = proc.rect.x() + 0.5 * (proc_rect_wd - prog_bar_wd),
            pb_y = proc.rect.y() + 38;

        this.inner_rect = (dgrp
                           .rect(0, 10).move(pb_x, pb_y)
                           .fill('#444').stroke('none'));

        this.outer_rect = (dgrp
                           .rect(prog_bar_wd, 10).move(pb_x, pb_y)
                           .fill('none').stroke(stroke_spec));
    }

    ProgressBar.prototype.start = function() {
        this.start_time = n_cycles_elapsed;
        this.inner_rect.width(0);
    }

    ProgressBar.prototype.tick = function() {
        if (this.proc.busy_p()) {
            var n_cycles_done = n_cycles_elapsed - this.start_time;
            var fraction_done = n_cycles_done / 296.0;  // HEM HEM we know the duration.
            this.inner_rect.width(prog_bar_wd * fraction_done);
        }
    }

    ////////////////////////////////////////////////////////////////////////

    function Process(name, label, x, y, ht) {
        this.name = name;
        this.label = label;
        this.x = x;
        this.y = y;
        this.ht = ht || 1;
        this.datum_idx = 0;
        this.rect = null;
        this.source = null;
        this.destination = null;
        this.progress_bar = null;
    }

    Process.prototype.start_work_on = function(d) {
        this.set_datum(d);

        if (this.progress_bar !== null)
            this.progress_bar.start();
    }

    Process.prototype.set_datum = function(d) {
        this.datum_idx = d;
        this.rect.fill(Datum_Colours[d]);
    }

    Process.prototype.src = function(n) {
        var src_slot = slot_f_name[n];
        this.source = src_slot;
        src_slot.n_consumers++;
        return this;
    }

    Process.prototype.dst = function(n) {
        this.destination = slot_f_name[n];
        return this;
    }

    Process.prototype.busy_p = function() {
        return this.datum_idx != 0;
    }

    Process.prototype.reset = function() {
        this.start_work_on(0);
    }

    Process.prototype.enable_progress_bar = function() {
        this.progress_bar = new ProgressBar(this);
        all_progress_bars.push(this.progress_bar);
    }

    ////////////////////////////////////////////////////////////////////////

    function DataSlot(name, label, x, y, wd) {
        this.name = name;
        this.label = label;
        this.x = x;
        this.y = y;
        this.wd = wd;
        this.n_refs = 0;
        this.n_consumers = 0;
        this.n_producers_done = 0;
        this.n_producers_needed = 1;
        this.aggregator = null;
    }

    DataSlot.prototype.release_consumer = function() {
        this.n_refs--;
        if (this.n_refs == 0)
            this.set_datum(0);
    }

    DataSlot.prototype.production_started = function(d) {
        this.production_started_at = n_cycles_elapsed;
        this.n_producers_done = 0;
        this.set_datum(d, true);

        if (this.aggregator !== null) {
            var agg = this.aggregator;
            agg.datum_idx = d;
            if (agg.n_producers_done == agg.n_producers_needed)
                agg.n_producers_done = 0;
        }
    }

    DataSlot.prototype.production_done = function() {
        this.n_producers_done++;
        if (this.n_producers_done == this.n_producers_needed) {
            this.set_datum(this.datum_idx);
            this.n_refs = this.n_consumers;
        }
    }

    DataSlot.prototype.set_datum = function(d, half) {
        half = half || false;
        this.datum_idx = d;
        this.rect.fill(half ? Datum_Half_Colours[d] : Datum_Colours[d]);
    }

    DataSlot.prototype.completed = function() {
        this.completed_p = true;
    }

    DataSlot.prototype.reset = function() {
        this.n_refs = 0;
        this.n_producers_done = 0;
        this.set_datum(0);
    }

    ////////////////////////////////////////////////////////////////////////

    var slot_default_wd = 16,
        slot_scv_wd = 58,
        slot_x00 = 0, slot_x01 = 19,
        slot_x10 = 41, slot_x11 = 60,
        slot_scv_x = 0.5 * (slot_x11 + slot_default_wd - slot_scv_wd),
        slot_x0h = 0.5 * (slot_x00 + slot_x01),
        slot_x1h = 0.5 * (slot_x10 + slot_x11),
        slot_xh = 0.5 * (slot_x00 + slot_x11),
        slot_sp_wd = slot_x01 - slot_x00 + slot_default_wd;

    ////////////////////////////////////////////////////////////////////////

    function PrinterSpool(grp, paper_wd, total_n_blocks) {
        this.contents = [];
        this.output_grp = grp.group();
        this.arrow_grp = grp.group();
        this.output_block_wd = 14;
        this.output_block_stride = 17;
        this.total_n_blocks = total_n_blocks;
        this.paper_wd = paper_wd;

        var total_output_wd
            = ((total_n_blocks - 1) * this.output_block_stride
               + this.output_block_wd);

        this.output_x0 = 0.5 * (paper_wd - total_output_wd);
    }

    PrinterSpool.prototype.reset = function() {
        this.contents = [];
        this.output_grp.clear();
    }

    PrinterSpool.prototype.production_started = function(d) {
        this.datum_idx = d;

        var new_output_x = (this.contents.length * this.output_block_stride
                            + this.output_x0);

        var half_colour = Datum_Half_Colours[this.datum_idx];
        var colour = Datum_Colours[this.datum_idx];

        var output_underway = (this
                               .output_grp
                               .rect(14, 20)
                               .move(new_output_x, 80)
                               .fill(half_colour)
                               .stroke('none'));
        this.contents.push(output_underway);

        var src_idx = this.contents.length % 2;
        var src_x = x_scale * (((src_idx == 0) ? slot_x0h : slot_x1h)
                               + 0.5 * slot_default_wd);

        this.arrow_grp
            .path('M ' + (new_output_x + this.output_block_wd / 2) + ' 76'
                  + ' v -30'
                  + ' H ' + src_x
                  + ' v -50')
            .fill('none')
            .stroke({color: colour, width: this.output_block_wd});
    }

    PrinterSpool.prototype.production_done = function() {
        this.arrow_grp.clear();
        var last_rect = this.contents[this.contents.length - 1];
        last_rect.fill(Datum_Colours[this.datum_idx]);
    }

    ////////////////////////////////////////////////////////////////////////

    var slots = [
        new DataSlot('trg', 'manual trigger',     slot_xh,    0),
        new DataSlot('scv', 'step-count vector',  slot_scv_x, 1, slot_scv_wd),
        new DataSlot('sp0', 'stepped pattern',    slot_x00,   2, slot_sp_wd),
        new DataSlot('sp1', 'stepped pattern',    slot_x10,   2, slot_sp_wd),
        new DataSlot('ap0', 'active pattern',     slot_x00,   3),
        new DataSlot('ap1', 'active pattern',     slot_x10,   3),
        new DataSlot('lv0', 'live counters',      slot_x00,   4),
        new DataSlot('lv1', 'live counters',      slot_x10,   4),
        new DataSlot('lt0', 'latched counters',   slot_x00,   5),
        new DataSlot('lt1', 'latched counters',   slot_x10,   5),
        new DataSlot('cc0', 'counter comparands', slot_x00,   6),
        new DataSlot('cc1', 'counter comparands', slot_x10,   6),
        new DataSlot('sl0', 'stepping labels',    slot_x01,   6),
        new DataSlot('sl1', 'stepping labels',    slot_x11,   6),
        new DataSlot('pr0', 'printer record',     slot_x0h,   6.4),
        new DataSlot('pr1', 'printer record',     slot_x1h,   6.4)];

    // A proc's 'x' is offset below such that using the same value here
    // as for a slot means the proc is centred in the slot.  Similary
    // for the 'y', the proc is offset to appear below a slot with the
    // same 'y'.
    //
    var procs = [
        new Process('gn',              'generate\nnext\nstepping', slot_xh,  0),
        new Process('d0',          'set\nstepped\npattern',    slot_x0h, 1),
        new Process('d1',          'set\nstepped\npattern',    slot_x1h, 1),
        new Process('sa0',    'reset\nmovement',          slot_x00, 2),
        new Process('sa1',    'reset\nmovement',          slot_x10, 2),
        new Process('al0',        'run tape once\n\n',        slot_x00, 3),
        new Process('al1',        'run tape once\n\n',        slot_x10, 3),
        new Process('ll0',       'latch\ncounter\nvalues',   slot_x00, 4),
        new Process('ll1',       'latch\ncounter\nvalues',   slot_x10, 4),
        new Process('lc0', 'load\ncomparands',         slot_x00, 5),
        new Process('lc1', 'load\ncomparands',         slot_x10, 5),
        new Process('sl0',    'copy\nsettings',           slot_x01, 2, 4),
        new Process('sl1',    'copy\nsettings',           slot_x11, 2, 4),
        new Process('p0',               'maybe\nprint',             slot_x0h, 6.4),
        new Process('p1',               'maybe\nprint',             slot_x1h, 6.4)]

    ////////////////////////////////////////////////////////////////////////

    var proc_f_name = {};
    procs.forEach(function(p, i) {
        proc_f_name[p.name] = p;

        var raw_dx = p.x;
        var dx = raw_dx * x_scale;
        var dy = p.y * y_scale;
        var raw_ht = p.ht;
        var ht = 70 + y_scale * (raw_ht - 1);

        p.rect = (dgrp
                  .rect(proc_rect_wd, ht)
                  .move(x0 + 25 + dx, y0 + 35 + dy)
                  .stroke(stroke_spec));
        p.set_datum(0);

        var n_lines = 1 + p.label.match(/\n/g).length;
        var text_dy = (n_lines == 3) ? 0 : 5;

        dgrp.text(p.label)
            .move(x0 + 80 + dx, y0 + 18 + text_dy + dy + ht / 2)
            .font(text_spec_i);
    });

    var slot_f_name = {};
    slots.forEach(function(s, i) {
        slot_f_name[s.name] = s;

        var wd = (s.wd || slot_default_wd) * x_scale;
        var dx = s.x * x_scale;
        var dy = s.y * y_scale;

        s.rect = (dgrp
                  .rect(wd, 40)
                  .move(x0 + dx, y0 + dy)
                  .radius(20)
                  .stroke(stroke_spec));
        s.set_datum(0);

        s.text = (dgrp
                  .text(s.label)
                  .move(x0 + wd / 2 + dx, y0 + 17 + dy)
                  .font(text_spec));
    });

    ////////////////////////////////////////////////////////////////////////

    proc_f_name['gn'].src('trg').dst('scv');
    proc_f_name['d0'].src('scv').dst('sp0');
    proc_f_name['d1'].src('scv').dst('sp1');
    proc_f_name['sa0'].src('sp0').dst('ap0');
    proc_f_name['sa1'].src('sp1').dst('ap1');
    proc_f_name['al0'].src('ap0').dst('lv0');
    proc_f_name['al1'].src('ap1').dst('lv1');
    proc_f_name['ll0'].src('lv0').dst('lt0');
    proc_f_name['ll1'].src('lv1').dst('lt1');
    proc_f_name['lc0'].src('lt0').dst('cc0');
    proc_f_name['lc1'].src('lt1').dst('cc1');
    proc_f_name['sl0'].src('sp0').dst('sl0');
    proc_f_name['sl1'].src('sp1').dst('sl1');
    proc_f_name['p0'].src('pr0');
    proc_f_name['p1'].src('pr1');

    proc_f_name['al0'].enable_progress_bar();
    proc_f_name['al1'].enable_progress_bar();

    slot_f_name['scv'].n_consumers = 1;

    slot_f_name['cc0'].aggregator = slot_f_name['pr0'];
    slot_f_name['cc0'].n_consumers = 1;
    slot_f_name['sl0'].aggregator = slot_f_name['pr0'];
    slot_f_name['sl0'].n_consumers = 1;
    slot_f_name['cc1'].aggregator = slot_f_name['pr1'];
    slot_f_name['cc1'].n_consumers = 1;
    slot_f_name['sl1'].aggregator = slot_f_name['pr1'];
    slot_f_name['sl1'].n_consumers = 1;

    ////////////////////////////////////////////////////////////////////////

    slot_f_name['pr0'].n_producers_needed = 2;
    slot_f_name['pr1'].n_producers_needed = 2;

    slot_f_name['pr0'].release_consumer = function() {
        DataSlot.prototype.release_consumer.call(this);
        slot_f_name['cc0'].release_consumer();
        slot_f_name['sl0'].release_consumer();
    }
    slot_f_name['cc0'].production_done = function() {
        DataSlot.prototype.production_done.call(this);
        slot_f_name['pr0'].production_done();
    }
    slot_f_name['sl0'].production_done = function(d) {
        DataSlot.prototype.production_done.call(this);
        slot_f_name['pr0'].production_done();
    }

    slot_f_name['pr1'].release_consumer = function() {
        DataSlot.prototype.release_consumer.call(this);
        slot_f_name['cc1'].release_consumer();
        slot_f_name['sl1'].release_consumer();
    }
    slot_f_name['cc1'].production_done = function() {
        DataSlot.prototype.production_done.call(this);
        slot_f_name['pr1'].production_done();
    }
    slot_f_name['sl1'].production_done = function(d) {
        DataSlot.prototype.production_done.call(this);
        slot_f_name['pr1'].production_done();
    }

    ////////////////////////////////////////////////////////////////////////

    var printer_paper_wd = (slot_x11 + slot_default_wd - slot_x00) * x_scale;
    var printer_paper_grp = dgrp.group().move(x0, y0 + 7.4 * y_scale);
    printer_paper_grp
        .rect(printer_paper_wd, 120)
        .radius(10)
        .stroke(stroke_spec)
        .fill('#eee');
    printer_paper_grp
        .text('printer paper')
        .move(slot_x00 * x_scale + 0.5 * printer_paper_wd, 14)
        .font(text_spec);

    // This is a short run on a 41-cam wheel.
    var printer_spool = new PrinterSpool(printer_paper_grp,
                                         printer_paper_wd,
                                         41);

    proc_f_name['p0'].destination = printer_spool;
    proc_f_name['p1'].destination = printer_spool;

    ////////////////////////////////////////////////////////////////////////

    var datum_idx;
    function next_datum_idx() {
        datum_idx++;
        if (datum_idx == Datum_Colours.length)
            datum_idx = 1;
        return datum_idx;
    }

    ////////////////////////////////////////////////////////////////////////

    var n_cycles_elapsed, ev_idx, phase, gen_phase;

    var replay_cycle = function() {
        n_cycles_elapsed++;

        all_progress_bars.forEach(function(pb) { pb.tick(); });

        var ev = Events[ev_idx];

        if (n_cycles_elapsed < ev[0]) {
            window.requestAnimationFrame(replay_cycle);
            return;
        }

        ev[1].forEach(function(n) {
            if (phase.hasOwnProperty(n)) {
                var ph = Math.floor(phase[n] / 2);
                phase[n]++;
                if (phase[n] == 4) phase[n] = 0;
                n = n + '' + ph;
            }

            var proc = proc_f_name[n];

            if (proc.busy_p()) {
                proc.set_datum(0);
                proc.source.release_consumer();
                proc.destination.production_done();
            } else {
                var d = (n == 'gn'
                         ? next_datum_idx() : proc.source.datum_idx);
                proc.start_work_on(d);
                proc.destination.production_started(d);
            }
        });

        ev_idx++;

        if (ev_idx == Events.length) {
            slot_f_name['trg'].rect.fill('#eee');
            enable_click();
        } else
            window.requestAnimationFrame(replay_cycle);
    };

    ////////////////////////////////////////////////////////////////////////

    var manual_trigger_elts = [slot_f_name['trg'].rect,
                               slot_f_name['trg'].text];

    function enable_click() {
        manual_trigger_elts.forEach(function(elt) {
            elt.click(launch_animation);
            elt.style('cursor', 'pointer');
        });
    }

    function disable_click() {
        manual_trigger_elts.forEach(function(elt) {
            elt.click(null);
            elt.style('cursor', 'default');
        });
    }

    function launch_animation() {
        n_cycles_elapsed = -1;
        ev_idx = 0;
        phase = {'d': 2, 'p': 2};
        gen_phase = 0;
        datum_idx = 0;

        procs.forEach(function(p) { proc_f_name[p.name].reset(); });
        slots.forEach(function(s) { slot_f_name[s.name].reset(); });
        printer_spool.reset();

        slot_f_name['trg'].rect.fill('#ff2');
        window.requestAnimationFrame(replay_cycle);
        disable_click();
    }

    ////////////////////////////////////////////////////////////////////////

    enable_click();
});
