/*

Copyright 2016 Ben North

This file is part of "FPGA Colossus".

"FPGA Colossus" is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

"FPGA Colossus" is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along with
"FPGA Colossus".  If not, see <http://www.gnu.org/licenses/>.

*/

////////////////////////////////////////////////////////////////////////

/*

This program should be built on the Raspberry Pi, having first installed
Mike McCauley's bcm2835 GPLv2-licensed library:

http://www.airspayce.com/mikem/bcm2835/

Tested against v1.49 but later versions might well work too.

With that library installed, the following should build the RPi client
to drive the FPGA Colossus:

cmake .
make

*/


#include <iostream>
#include <fstream>
#include <cstdint>
#include <vector>
#include <stdexcept>

#include "bcm2835.h"

using std::cout;
using std::endl;

using Pin_ID_t = uint8_t;
using Pin_ID_Vec_t = std::vector<Pin_ID_t>;

struct Response
{
    bool error_p;
    uint8_t value;

    Response(bool error_p, uint8_t value)
        : error_p(error_p), value(value)
        {}

    Response()
        : Response(false, 0)
        {}
};

std::ostream & operator<<(std::ostream & os, const Response & response)
{
    os << (response.error_p ? "'1' " : "'0' ")
       << static_cast<int>(response.value);
    return os;
}

class Colossus
{
public:
    Colossus();

    Response submit_data(uint8_t data);
    Response submit_addr_data(uint8_t addr, uint8_t data);

private:
    void _drive_data_addr_muxd(uint8_t value, uint8_t sel);
    void _handshake();
    void _drive_req(uint8_t req);
    void _wait_for_busy(uint8_t target_busy);

    void _drive_8bit_signal(const Pin_ID_Vec_t & pins, uint8_t val);
    void _drive_1bit_signal(Pin_ID_t pin, uint8_t val);

    uint8_t _read_8bit_signal(const Pin_ID_Vec_t & pins);
    Response _response();

    // Output from RPi:
    static const Pin_ID_Vec_t _data_addr_muxd_pins;
    static const Pin_ID_t _data_addr_sel_pin;
    static const Pin_ID_t _req_pin;
    //
    // Input to RPi:
    static const Pin_ID_t _busy_pin;
    static const Pin_ID_t _response_err_pin;
    static const Pin_ID_Vec_t _response_pins;
};

// Vectors of pin assignment for 8-bit signals are from most-significant
// bit (7) down-to least-significant (0).

const Pin_ID_Vec_t Colossus::_data_addr_muxd_pins({
            RPI_V2_GPIO_P1_31,   // (7)
            RPI_V2_GPIO_P1_33,   // (6)
            RPI_V2_GPIO_P1_35,   // (5)
            RPI_V2_GPIO_P1_37,   // (4)
            RPI_V2_GPIO_P1_32,   // (3)
            RPI_V2_GPIO_P1_36,   // (2)
            RPI_V2_GPIO_P1_38,   // (1)
            RPI_V2_GPIO_P1_26}); // (0)
const Pin_ID_t Colossus::_data_addr_sel_pin = RPI_V2_GPIO_P1_29;
const Pin_ID_t Colossus::_req_pin = RPI_V2_GPIO_P1_40;
//
const Pin_ID_t Colossus::_busy_pin = RPI_V2_GPIO_P1_11;
const Pin_ID_t Colossus::_response_err_pin = RPI_V2_GPIO_P1_13;
const Pin_ID_Vec_t Colossus::_response_pins({
            RPI_V2_GPIO_P1_15,   // (7)
            RPI_V2_GPIO_P1_19,   // (6)
            RPI_V2_GPIO_P1_21,   // (5)
            RPI_V2_GPIO_P1_23,   // (4)
            RPI_V2_GPIO_P1_16,   // (3)
            RPI_V2_GPIO_P1_18,   // (2)
            RPI_V2_GPIO_P1_22,   // (1)
            RPI_V2_GPIO_P1_24}); // (0)

Colossus::Colossus()
{
    if (bcm2835_init() == 0)
        throw std::runtime_error("failed to init bcm2835");

    bcm2835_gpio_fsel(_data_addr_sel_pin, BCM2835_GPIO_FSEL_OUTP);
    bcm2835_gpio_fsel(_req_pin, BCM2835_GPIO_FSEL_OUTP);
    for (auto pin : _data_addr_muxd_pins)
        bcm2835_gpio_fsel(pin, BCM2835_GPIO_FSEL_OUTP);

    bcm2835_gpio_fsel(_busy_pin, BCM2835_GPIO_FSEL_INPT);
    bcm2835_gpio_fsel(_response_err_pin, BCM2835_GPIO_FSEL_INPT);
    for (auto pin : _response_pins)
        bcm2835_gpio_fsel(pin, BCM2835_GPIO_FSEL_INPT);
}

void Colossus::_handshake()
{
    _drive_req(1);
    _wait_for_busy(1);
    _drive_req(0);
    _wait_for_busy(0);
}

Response Colossus::submit_data(uint8_t data)
{
    _drive_data_addr_muxd(data, 1);
    _handshake();
    return _response();
}

Response Colossus::submit_addr_data(uint8_t addr, uint8_t data)
{
    _drive_data_addr_muxd(addr, 0);
    _handshake();

    submit_data(data);
    return _response();
}

Response Colossus::_response()
{
    return Response(bcm2835_gpio_lev(_response_err_pin) == 1,
                    _read_8bit_signal(_response_pins));
}

uint8_t Colossus::_read_8bit_signal(const Pin_ID_Vec_t & pins)
{
    uint8_t value = 0;

    for (auto pin : pins)
    {
        value <<= 1;
        if (bcm2835_gpio_lev(pin) == 1)
            value |= 0x01;
    }

    return value;
}

void Colossus::_drive_8bit_signal(const Pin_ID_Vec_t & pins, uint8_t val)
{
    for (auto pin : pins)
    {
        if (val & 0x80)
            bcm2835_gpio_set(pin);
        else
            bcm2835_gpio_clr(pin);
        val <<= 1;
    }
}

void Colossus::_drive_1bit_signal(Pin_ID_t pin, uint8_t val)
{
    if (val)
        bcm2835_gpio_set(pin);
    else
        bcm2835_gpio_clr(pin);
}

void Colossus::_drive_data_addr_muxd(uint8_t value, uint8_t sel)
{
    _drive_8bit_signal(_data_addr_muxd_pins, value);
    _drive_1bit_signal(_data_addr_sel_pin, sel);
}

void Colossus::_drive_req(uint8_t req)
{
    _drive_1bit_signal(_req_pin, req);
}

void Colossus::_wait_for_busy(uint8_t target_busy)
{
    while (bcm2835_gpio_lev(_busy_pin) != target_busy)
    {
        // Do nothing;
    }
}

int main(int argc, char **argv)
{
    Colossus colossus;

    cout << "READY-FOR-INPUT" << endl;

    std::ifstream in_cmd_file("/tmp/repl-input");
    std::string cmd_line;

    while (std::getline(in_cmd_file, cmd_line))
    {
        unsigned int addr, data;
        bool valid_p = false;
        Response response;

        cout << "COLOSSUS-RESPONSE: ";

        switch (cmd_line.length())
        {
        case 4:
            sscanf(cmd_line.c_str(), "%02x%02x", &addr, &data);
            response = colossus.submit_addr_data(addr, data);
            valid_p = true;
            break;
        case 2:
            sscanf(cmd_line.c_str(), "%02x", &data);
            response = colossus.submit_data(data);
            valid_p = true;
            break;
        default:
            cout << "?\n";
        }

        if (valid_p)
            cout << cmd_line << ' ' << response << "\n";

        cout.flush();
    }

    return 0;
}
