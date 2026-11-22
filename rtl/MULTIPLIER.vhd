-- =============================================================================
-- MULTIPLIER.vhd
-- The only multiplier of the butterfly. It can also multiply A by 2 (shift).
--   S_SH = 1: M_OUT = A * B, with 2 pipeline stages (result after 2 clock edges)
--   S_SH = 0: SH_OUT = 2 * A, with 1 pipeline stage (result after 1 clock edge)
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;

ENTITY MULTIPLIER IS
    PORT( A, B:   IN  signed(23 downto 0);   -- operands (Q1.23 format)
          CLK,S_SH: IN std_logic;            -- S_SH: 1 = multiply, 0 = shift
          M_OUT : OUT signed(47 downto 0);   -- product A*B (Q2.46 format)
          SH_OUT: OUT signed(24 downto 0));  -- 2*A on 25 bits
    END MULTIPLIER ;

ARCHITECTURE Behavior OF MULTIPLIER IS
BEGIN

PROCESS(CLK,A,B)
    -- PRODUCT_STAGE1 keeps its value between clock edges, so it works as the
    -- first pipeline register of the multiplication.
    variable PRODUCT, PRODUCT_STAGE1: signed(47 downto 0);
    variable SHIFTED:  signed(24 downto 0);       -- 2*A

    variable OPERAND_A,OPERAND_B :signed(23 downto 0);
BEGIN



    OPERAND_A:=A; OPERAND_B:=B;

    PRODUCT:=OPERAND_A*OPERAND_B;   -- full product on 48 bits

    SHIFTED:=OPERAND_A & '0';       -- shift left by 1 = multiply by 2 (25 bits)
    IF (rising_edge(CLK) ) THEN
        -- 2nd pipeline stage: the product saved at the previous edge goes out
        M_OUT <= PRODUCT_STAGE1;
        IF (S_SH='0') THEN
            -- shift: the result is ready after this edge
            SH_OUT(24 downto 0)<=  SHIFTED;
        ELSE
            -- multiplication: 1st pipeline stage
            PRODUCT_STAGE1:=  PRODUCT;
        END if;
    END if;
END PROCESS;



END Behavior;
