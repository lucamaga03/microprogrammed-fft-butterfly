-- =============================================================================
-- TB_ADDER_SUBTRACTOR.vhd
-- Testbench of the adder and of the subtractor (49 bits). Clock period: 10 ns.
-- Both get the same inputs: O_ADD = A + B and O_SUB = A - B, one clock edge later.
-- Here the values are integers. Numbers in brackets are the hex values of the
-- results, as in the waveforms (49 bits).
-- The test process starts again from the beginning after the last test.
-- =============================================================================
LIBRARY ieee ;
USE ieee . std_logic_1164 .all;
USE ieee.numeric_std.all;

ENTITY TB_ADDER_SUBTRACTOR IS
END TB_ADDER_SUBTRACTOR ;

ARCHITECTURE tb OF TB_ADDER_SUBTRACTOR IS

COMPONENT ADDER IS
    PORT( A, B: IN  signed(48 downto 0);
          CLK:  IN  std_logic;
          O:    OUT signed(48 downto 0));
END COMPONENT ;

COMPONENT SUBTRACTOR IS
    PORT( A, B: IN  signed(48 downto 0);
          CLK:  IN  std_logic;
          O:    OUT signed(48 downto 0));
END COMPONENT ;


signal in_A,in_B: signed(48 downto 0);
signal out_O_ADD:   signed(48 downto 0);   -- A + B
signal out_O_SUB:   signed(48 downto 0);   -- A - B
signal Ck_tb : std_logic;

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

wait for 16 ns; -- 1 cycle + 6 ns of delay

in_A <=  to_signed(512, 49);    -- sum 1536 (0000000000600), difference -512 (1FFFFFFFFFE00)
in_B <=  to_signed(1024, 49);

wait for 10 ns; -- 1 more cycle
in_A <=  to_signed(512, 49);    -- sum -512 (1FFFFFFFFFE00), difference 1536 (0000000000600)
in_B <=  to_signed(-1024, 49);

wait for 10 ns; -- 1 more cycle
in_A <=  to_signed(-512, 49);   -- sum 512 (0000000000200), difference -1536 (1FFFFFFFFFA00)
in_B <=  to_signed(1024, 49);

wait for 10 ns; -- 1 more cycle
in_A <=  to_signed(-512, 49);   -- sum -1536 (1FFFFFFFFFA00), difference 512 (0000000000200)
in_B <=  to_signed(-1024, 49);


END PROCESS TEST ;

ADD : ADDER port map( A => in_A, B => in_B , CLK => Ck_tb ,  O => out_O_ADD);

SUB : SUBTRACTOR port map( A => in_A, B => in_B , CLK => Ck_tb ,  O => out_O_SUB);

END tb;
