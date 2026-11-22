-- =============================================================================
-- ROM_ROUNDING_COMP.vhd
-- Rounding ROM: round to nearest, ties to even, with a look-up table.
-- Address (7 bits) = IN_L & IN_D:
--   IN_L = the 5 lowest bits that are kept, IN_D = the next 2 bits (guard bits).
-- DOUT = IN_L after rounding. It saturates at "11111", so there is never a carry
-- out: the other bits of the result do not change.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;


entity ROM_ROUNDING_COMP is
    generic(
        L : integer := 5;     -- number of bits to round
        D : integer := 2);    -- number of guard bits
    port(
        CLK:    in std_logic;   -- not used: the ROM has no clock
        IN_L: in std_logic_vector(L-1 downto 0);    -- bits to round
        IN_D: in std_logic_vector(D-1 downto 0);    -- guard bits (they are dropped)
        DOUT : out  std_logic_vector(L-1 DOWNTO 0));  -- rounded bits
    end ROM_ROUNDING_COMP;


ARCHITECTURE Behavior OF ROM_ROUNDING_COMP IS

-- 128 words of 5 bits
type rom is array (2**(7)-1 downto 0) of std_logic_vector(5-1 DOWNTO 0);

signal full_address : std_logic_vector(6 downto 0);
-- Range 127 downto 0: the first value is at address 127 (IN_L = 11111, IN_D = 11).
-- Rule: IN_D = 00 or 01 -> IN_L;   IN_D = 11 -> IN_L + 1;
--       IN_D = 10 (exactly half) -> IN_L if IN_L is even, IN_L + 1 if IN_L is odd.
constant round_rom : rom := (
        "11111", "11111", "11111", "11111", "11111",
        "11110", "11110", "11110", "11110", "11110",
        "11101", "11101", "11101",
        "11100", "11100", "11100", "11100", "11100",
        "11011", "11011", "11011",
        "11010", "11010", "11010", "11010", "11010",
        "11001", "11001", "11001",
        "11000", "11000", "11000", "11000", "11000",
        "10111", "10111", "10111",
        "10110", "10110", "10110", "10110", "10110",
        "10101", "10101", "10101",
        "10100", "10100", "10100", "10100", "10100",
        "10011", "10011", "10011",
        "10010", "10010", "10010", "10010", "10010",
        "10001", "10001", "10001",
        "10000", "10000", "10000", "10000", "10000",
        "01111", "01111", "01111",
        "01110", "01110", "01110", "01110", "01110",
        "01101", "01101", "01101",
        "01100", "01100", "01100", "01100", "01100",
        "01011", "01011", "01011",
        "01010", "01010", "01010", "01010", "01010",
        "01001", "01001", "01001",
        "01000", "01000", "01000", "01000", "01000",
        "00111", "00111", "00111",
        "00110", "00110", "00110", "00110", "00110",
        "00101", "00101", "00101",
        "00100", "00100", "00100", "00100", "00100",
        "00011", "00011", "00011",
        "00010", "00010", "00010", "00010", "00010",
        "00001", "00001", "00001",
        "00000", "00000", "00000");



BEGIN

-- the address joins the bits to round and the guard bits
full_address <= IN_L & IN_D;
DOUT <= round_rom(to_integer(unsigned(full_address)));

END Behavior;
