-- =============================================================================
-- TB_MULTIPLIER.vhd
-- Testbench of the multiplier / shifter. Clock period: 10 ns.
--  - S_SH = '1': M_OUT = A * B, two clock edges after the inputs.
--  - S_SH = '0': SH_OUT = 2 * A, one clock edge after the inputs.
-- Here the values are integers. Numbers in brackets are the hex values of the
-- results, as in the waveforms (M_OUT: 48 bits, SH_OUT: 25 bits).
-- =============================================================================
LIBRARY ieee ;
USE ieee . std_logic_1164 .all;
USE ieee.numeric_std.all;

ENTITY TB_MULTIPLIER IS
END TB_MULTIPLIER ;

ARCHITECTURE tb OF TB_MULTIPLIER IS


COMPONENT MULTIPLIER IS
    PORT( A, B: IN  signed(23 downto 0);
          CLK,S_SH: IN  std_logic;
          SH_OUT:   OUT signed(24 downto 0);
          M_OUT:    OUT signed(47 downto 0));
END COMPONENT ;


signal M_OUT_tb: signed(47 downto 0);
signal in_A, in_B:  signed(23 downto 0);
signal SH_OUT_tb: signed(24 downto 0);
signal Ck_tb, S_SH_tb : std_logic;

BEGIN

-- clock: period 10 ns
clock : PROCESS
BEGIN
Ck_tb <= '0';
WAIT FOR 5 ns;
Ck_tb <= '1';
WAIT FOR 5 ns;
END PROCESS clock ;


TEST : PROCESS
BEGIN


-- multiplication tests
S_SH_tb<='1';

wait for 16 ns; -- 1 cycle + 6 ns of delay

in_A <=  to_signed(-1, 24);     -- -1 * 800 = -800 (FFFFFFFFFCE0)
in_B <=  to_signed(800, 24);

wait for 10 ns; -- 1 more cycle
in_A <=  "100000000000000000000000";    -- (-2^23) * (-2^23) = 2^46, the largest product (400000000000)
in_B <=  "100000000000000000000000";



wait for 10 ns;
in_A <=  "100000000000000000000000";    -- (-2^23) * (-800) = 6710886400 (000190000000)
in_B <=  to_signed(-800, 24);

wait for 10 ns;
in_A <=  to_signed(-4, 24);     -- -4 * 0 = 0 (000000000000)
in_B <=  to_signed(0, 24);

wait for 10 ns;
in_A <=  to_signed(10, 24);     -- 10 * (-8) = -80 (FFFFFFFFFFB0)
in_B <=  to_signed(-8, 24);


wait for 10 ns;
in_A <=  to_signed(4, 24);      -- 4 * (-8) = -32 (FFFFFFFFFFE0)
in_B <=  to_signed(-8, 24);

wait for 10 ns;
in_A <=  to_signed(-4, 24);     -- -4 * (-8) = 32 (000000000020)
in_B <=  to_signed(-8, 24);

-- wait one cycle, so that the multiplier takes the last product
wait for 10 ns;

-- shift tests (B is not used)
S_SH_tb<='0';
wait for 10 ns;
in_A <=  to_signed(-4, 24);     -- 2 * (-4) = -8 (1FFFFF8)
in_B <=  to_signed(8, 24);

wait for 10 ns;
in_A <=  to_signed(+4, 24);     -- 2 * 4 = 8 (0000008)
in_B <=  to_signed(8, 24);

-- end of the tests: the process stops here
wait;

END PROCESS TEST ;


MUL : MULTIPLIER port map( A => in_A, B => in_B , CLK => Ck_tb , S_SH=> S_SH_tb,
                           SH_OUT => SH_OUT_tb,  M_OUT => M_OUT_tb);


END tb;
