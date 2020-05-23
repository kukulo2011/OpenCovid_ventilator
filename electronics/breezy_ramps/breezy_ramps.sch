EESchema Schematic File Version 4
EELAYER 29 0
EELAYER END
$Descr A4 11693 8268
encoding utf-8
Sheet 1 1
Title ""
Date ""
Rev ""
Comp ""
Comment1 ""
Comment2 ""
Comment3 ""
Comment4 ""
$EndDescr
$Comp
L arduino:Arduino_Mega2560_Shield XA?
U 1 1 5EC2DED6
P 4850 3550
F 0 "XA?" H 4850 1169 60  0000 C CNN
F 1 "Arduino_Mega2560_Shield" H 4850 1063 60  0000 C CNN
F 2 "" H 5550 6300 60  0001 C CNN
F 3 "https://store.arduino.cc/arduino-mega-2560-rev3" H 5550 6300 60  0001 C CNN
	1    4850 3550
	1    0    0    -1  
$EndComp
$Comp
L Device:R_POT RV?
U 1 1 5EC34AA8
P 850 1750
F 0 "RV?" H 781 1796 50  0000 R CNN
F 1 "10k lin" H 781 1705 50  0000 R CNN
F 2 "" H 850 1750 50  0001 C CNN
F 3 "~" H 850 1750 50  0001 C CNN
	1    850  1750
	1    0    0    -1  
$EndComp
Text GLabel 3450 5400 0    50   Input ~ 0
5V
Wire Wire Line
	3450 5400 3550 5400
Text GLabel 3450 4800 0    50   Input ~ 0
GND
Wire Wire Line
	3450 4800 3550 4800
Text GLabel 850  2000 3    50   Input ~ 0
GND
Text GLabel 850  1500 1    50   Input ~ 0
5V
Wire Wire Line
	850  1900 850  2000
Wire Wire Line
	850  1500 850  1600
$Comp
L Device:R_POT RV?
U 1 1 5EC39398
P 850 2700
F 0 "RV?" H 781 2746 50  0000 R CNN
F 1 "10k lin" H 781 2655 50  0000 R CNN
F 2 "" H 850 2700 50  0001 C CNN
F 3 "~" H 850 2700 50  0001 C CNN
	1    850  2700
	1    0    0    -1  
$EndComp
Text GLabel 850  2950 3    50   Input ~ 0
GND
Text GLabel 850  2450 1    50   Input ~ 0
5V
Wire Wire Line
	850  2850 850  2950
Wire Wire Line
	850  2450 850  2550
$Comp
L Device:R_POT RV?
U 1 1 5EC39A4F
P 850 3650
F 0 "RV?" H 781 3696 50  0000 R CNN
F 1 "10k lin" H 781 3605 50  0000 R CNN
F 2 "" H 850 3650 50  0001 C CNN
F 3 "~" H 850 3650 50  0001 C CNN
	1    850  3650
	1    0    0    -1  
$EndComp
Text GLabel 850  3900 3    50   Input ~ 0
GND
Text GLabel 850  3400 1    50   Input ~ 0
5V
Wire Wire Line
	850  3800 850  3900
Wire Wire Line
	850  3400 850  3500
$Comp
L Device:R_POT RV?
U 1 1 5EC3D9FD
P 1700 1750
F 0 "RV?" H 1631 1796 50  0000 R CNN
F 1 "10k lin" H 1631 1705 50  0000 R CNN
F 2 "" H 1700 1750 50  0001 C CNN
F 3 "~" H 1700 1750 50  0001 C CNN
	1    1700 1750
	1    0    0    -1  
$EndComp
Text GLabel 1700 2000 3    50   Input ~ 0
GND
Text GLabel 1700 1500 1    50   Input ~ 0
5V
Wire Wire Line
	1700 1900 1700 2000
Wire Wire Line
	1700 1500 1700 1600
$Comp
L Device:R_POT RV?
U 1 1 5EC3DA07
P 1700 2700
F 0 "RV?" H 1631 2746 50  0000 R CNN
F 1 "10k lin" H 1631 2655 50  0000 R CNN
F 2 "" H 1700 2700 50  0001 C CNN
F 3 "~" H 1700 2700 50  0001 C CNN
	1    1700 2700
	1    0    0    -1  
$EndComp
Text GLabel 1700 2950 3    50   Input ~ 0
GND
Text GLabel 1700 2450 1    50   Input ~ 0
5V
Wire Wire Line
	1700 2850 1700 2950
Wire Wire Line
	1700 2450 1700 2550
$Comp
L Device:R_POT RV?
U 1 1 5EC3DA11
P 1700 3650
F 0 "RV?" H 1631 3696 50  0000 R CNN
F 1 "10k lin" H 1631 3605 50  0000 R CNN
F 2 "" H 1700 3650 50  0001 C CNN
F 3 "~" H 1700 3650 50  0001 C CNN
	1    1700 3650
	1    0    0    -1  
$EndComp
Text GLabel 1700 3900 3    50   Input ~ 0
GND
Text GLabel 1700 3400 1    50   Input ~ 0
5V
Wire Wire Line
	1700 3800 1700 3900
Wire Wire Line
	1700 3400 1700 3500
$EndSCHEMATC
