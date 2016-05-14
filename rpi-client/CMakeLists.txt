cmake_minimum_required (VERSION 2.8.11)
project (rpi-client)

add_definitions (-std=c++11)
add_executable (rpi-client client.cpp)
target_link_libraries (rpi-client bcm2835)
