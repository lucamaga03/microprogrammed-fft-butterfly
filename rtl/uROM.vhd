-- =============================================================================
-- uROM.vhd
-- Microprogram memory of the CU: two banks (EVEN and ODD) of 4 words of 23 bits.
-- Both banks are read at the same time, with the same address A and without clock.
-- State code = A & LSB: the EVEN bank has the codes ending in 0, the ODD bank
-- the codes ending in 1.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all ;
USE work.my_types_pkg.all;

ENTITY uROM IS
    GENERIC (
        ADDR_NUM_BIT : integer := 2;   -- address width (4 rows)
        DATA_NUM_BIT : integer := 23   -- word width
    );
    PORT(   A:  IN  STD_LOGIC_VECTOR((ADDR_NUM_BIT - 1) DOWNTO 0);   -- row address
            -- words of the EVEN and ODD bank at row A
            OUT_EVEN, OUT_ODD : OUT STD_LOGIC_VECTOR((DATA_NUM_BIT - 1) DOWNTO 0));
    END uROM ;

ARCHITECTURE Behavior OF uROM IS

type MEM is array(2**ADDR_NUM_BIT - 1 DOWNTO 0)
             of STD_LOGIC_VECTOR((DATA_NUM_BIT - 1) DOWNTO 0);


-- Contents of the two banks.
-- Fields of a word, from bit 22 down to bit 0:
--   [22:21] CC          [20:19] Next_Addr   [18] LSB
--   [17] SHN_MUL        [16] SEL_A          [15] SEL_OUT_B      [14] SEL_ADD_OUT
--   [13] SEL_ADD_IN2    [12] SEL_SUB_OUT    [11] SEL_SUB_IN1    [10] SEL_X_IN2
--   [9]  SEL_SH_OUT     [8]  SEL_ROUND      [7:6] SEL_X_IN1     [5:4] SEL_SUB_IN2
--   [3]  FF_SH_EN2      [2]  FF_SH_EN1      [1] FF_INR_EN       [0] EN_DONE
-- The range is 3 DOWNTO 0, so the first word of each list is at address 11.

-- EVEN bank (state codes ending in 0)
CONSTANT uROM_EVEN: MEM := (
    "00100010001000001001000",  -- address 11(0) - STATE5_NODONE
    "11000001000100000010110",  -- address 10(0) - STATE6
    "00011100000011011101100",  -- address 01(0) - STATE2
    "01000000000000000000010"   -- address 00(0) - IDLE
    );


-- ODD bank (state codes ending in 1)
CONSTANT uROM_ODD: MEM := (
    "00100010001000001001001",  -- address 11(1) - STATE5_DONE
    "10110100100000010000000",  -- address 10(1) - STATE4
    "00101100000011110001100",  -- address 01(1) - STATE3
    "00010100010000011001100"   -- address 00(1) - STATE1
    );




BEGIN

-- Two memories without clock, read with the same address

OUT_ODD  <= uROM_ODD(TO_INTEGER(UNSIGNED(A)));

OUT_EVEN <= uROM_EVEN(TO_INTEGER(UNSIGNED(A)));



END Behavior;
