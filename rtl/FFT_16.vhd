-- =============================================================================
-- FFT_16.vhd
-- 16-point FFT, radix-2, decimation in time: 4 columns of 8 butterflies.
-- x_IN is in natural order. The last column gives the results in a mixed
-- order; the assignments at the end put them back in natural order in X_OUT.
-- Column 1 shifts by 2 (SF_2H_1L = '1'), the other columns by 1: 5 bits in
-- total, so X_OUT = DFT(x_IN) / 32.
-- Each butterfly starts with the DONE of the butterfly in the same row of the
-- previous column. The DONE of the FFT is the DONE of row 0 of column 4.
-- As for one butterfly: real parts with START (or DONE), imaginary parts one
-- clock cycle later.
-- =============================================================================
LIBRARY ieee ;
USE ieee.std_logic_1164.all ;
USE ieee.numeric_std.all;
USE work.my_types_pkg.all;

ENTITY FFT_16 IS
    PORT(
            -- RES: asynchronous reset, RES_SINC: synchronous reset (both active low)
            CLK,RES,RES_SINC,START: IN  std_logic;
            x_IN:   IN  S_array(15 downto 0)(23 downto 0);  -- the 16 input samples (Q1.23)
            DONE:   out std_logic;
            X_OUT:  OUT S_array(15 downto 0)(23 downto 0)); -- the 16 results (Q1.23)
    END FFT_16;

ARCHITECTURE Behavior OF FFT_16 IS


    -- DONE of the 8 butterflies of each column
    signal DONE1,DONE2,DONE3,DONE4: std_logic_vector(7 downto 0);
    -- outputs of column 1 (A' and B' of each butterfly)
    signal A1_OUT,B1_OUT: S_array(7 downto 0)(23 downto 0);

    -- inputs and outputs of column 2
    signal A2_IN,B2_IN: S_array(7 downto 0)(23 downto 0);
    signal A2_OUT,B2_OUT: S_array(7 downto 0)(23 downto 0);

    -- inputs and outputs of column 3
    signal A3_IN,B3_IN: S_array(7 downto 0)(23 downto 0);
    signal A3_OUT,B3_OUT: S_array(7 downto 0)(23 downto 0);

    -- inputs and outputs of column 4
    signal A4_IN,B4_IN: S_array(7 downto 0)(23 downto 0);
    signal A4_OUT,B4_OUT: S_array(7 downto 0)(23 downto 0);


    -- W^k, k = 0..7: real part WR(k), imaginary part WI(k)
    SIGNAL  WR,WI:  S_array(7 downto 0)(23 downto 0);
    -- Index k of W^k for each butterfly of columns 2, 3 and 4.
    -- The range is 7 downto 0: the first number is for the butterfly in row 7.
    constant W_col2: INT_array(7 downto 0):=(4,4,4,4,0,0,0,0);  -- column 2
    constant W_col3: INT_array(7 downto 0):=(6,6,2,2,4,4,0,0);  -- column 3
    constant W_col4: INT_array(7 downto 0):=(7,3,5,1,6,2,4,0);  -- column 4

COMPONENT BUTTERFLY IS
    PORT( -- Inputs
            CLK,RES,RES_SINC,START,SF_2H_1L: IN  std_logic;
            WR,WI:          IN  signed(23 downto 0);
            x1_IN,x2_IN:    IN  signed(23 downto 0);
            -- Outputs
            X1_OUT,X2_OUT:  OUT signed(23 downto 0);
            DONE:           OUT std_logic);
    END COMPONENT;



-- W^k = cos(2*pi*k/16) - j*sin(2*pi*k/16), Q1.23 (only k = 0..7 are used)
--  k | Real (float)  | Real (binary)            | Imag (float)  | Imag (binary)
-- ---+---------------+--------------------------+---------------+-------------------------
--  0 | +1.0000000000 | 011111111111111111111111 | -0.0000000000 | 000000000000000000000000
--  1 | +0.9238795325 | 011101100100000110101111 | -0.3826834324 | 110011110000010000111011
--  2 | +0.7071067812 | 010110101000001001111010 | -0.7071067812 | 101001010111110110000110
--  3 | +0.3826834324 | 001100001111101111000101 | -0.9238795325 | 100010011011111001010001
--  4 | +0.0000000000 | 000000000000000000000000 | -1.0000000000 | 100000000000000000000000
--  5 | -0.3826834324 | 110011110000010000111011 | -0.9238795325 | 100010011011111001010001
--  6 | -0.7071067812 | 101001010111110110000110 | -0.7071067812 | 101001010111110110000110
--  7 | -0.9238795325 | 100010011011111001010001 | -0.3826834324 | 110011110000010000111011
--  8 | -1.0000000000 | 100000000000000000000000 | -0.0000000000 | 000000000000000000000000
--  9 | -0.9238795325 | 100010011011111001010001 | +0.3826834324 | 001100001111101111000101
-- 10 | -0.7071067812 | 101001010111110110000110 | +0.7071067812 | 010110101000001001111010
-- 11 | -0.3826834324 | 110011110000010000111011 | +0.9238795325 | 011101100100000110101111
-- 12 | -0.0000000000 | 000000000000000000000000 | +1.0000000000 | 011111111111111111111111
-- 13 | +0.3826834324 | 001100001111101111000101 | +0.9238795325 | 011101100100000110101111
-- 14 | +0.7071067812 | 010110101000001001111010 | +0.7071067812 | 010110101000001001111010
-- 15 | +0.9238795325 | 011101100100000110101111 | +0.3826834324 | 001100001111101111000101
-- Note: +1.0 does not exist in Q1.23, so it is written as the largest value, 1 - 2^-23.

BEGIN

-- W^0 ... W^7 (8 x 2 x 24 bits)

     WR(0)<="011111111111111111111111"; WI(0)<="000000000000000000000000";
     WR(1)<="011101100100000110101111"; WI(1)<="110011110000010000111011";
     WR(2)<="010110101000001001111010"; WI(2)<="101001010111110110000110";
     WR(3)<="001100001111101111000101"; WI(3)<="100010011011111001010001";
     WR(4)<="000000000000000000000000"; WI(4)<="100000000000000000000000";
     WR(5)<="110011110000010000111011"; WI(5)<="100010011011111001010001";
     WR(6)<="101001010111110110000110"; WI(6)<="101001010111110110000110";
     WR(7)<="100010011011111001010001"; WI(7)<="110011110000010000111011";


-- The FFT is done when the butterfly in row 0 of column 4 is done
DONE<=DONE4(0);


    -- COLUMN 1: butterfly i takes x(i) and x(i+8), with W^0. Shift by 2.
    COL1 : for i in 7 downto 0 generate
            BUTTERFLY_col1: BUTTERFLY PORT MAP(
                RES    => RES,
                RES_SINC    => RES_SINC,
                CLK    => CLK,
                SF_2H_1L  => '1',
                START  => START,
                DONE   => DONE1(i),
                x1_IN  => x_IN(i),      -- A
                x2_IN  => x_IN(i+8),    -- B
                WR => WR(0),
                WI => WI(0),
                X1_OUT => A1_OUT(i),
                X2_OUT => B1_OUT(i));
        END GENERATE COL1;

        -- Inputs of column 2:
        --   rows 0..3: A = A1_OUT(i),   B = A1_OUT(i+4)
        --   rows 4..7: A = B1_OUT(i-4), B = B1_OUT(i)
        A2_IN(3 downto 0)<=A1_OUT(3 downto 0);
        B2_IN(7 downto 4)<=B1_OUT(7 downto 4);
        -- crossed connections
        A2_IN(7 downto 4)<=B1_OUT(3 downto 0);
        B2_IN(3 downto 0)<=A1_OUT(7 downto 4);



    -- COLUMN 2: W^k with k = W_col2(i). Shift by 1.
    COL2 : for i in 7 downto 0 generate
            BUTTERFLY_col2: BUTTERFLY PORT MAP(
                RES    => RES,
                RES_SINC    => RES_SINC,
                CLK    => CLK,
                SF_2H_1L  => '0',
                START  => DONE1(i),
                DONE   => DONE2(i),
                x1_IN  => A2_IN(i),     -- A
                x2_IN  => B2_IN(i),     -- B
                WR     => WR(W_col2(i)),
                WI     => WI(W_col2(i)),
                X1_OUT => A2_OUT(i),
                X2_OUT => B2_OUT(i));
        END GENERATE COL2;


        -- Inputs of column 3 (direct connections)
        A3_IN(1 downto 0)<=A2_OUT(1 downto 0);
        A3_IN(5 downto 4)<=A2_OUT(5 downto 4);

        B3_IN(3 downto 2)<=B2_OUT(3 downto 2);
        B3_IN(7 downto 6)<=B2_OUT(7 downto 6);
        -- crossed connections
        A3_IN(3 downto 2)<=B2_OUT(1 downto 0);
        B3_IN(1 downto 0)<=A2_OUT(3 downto 2);

        A3_IN(7 downto 6)<=B2_OUT(5 downto 4);
        B3_IN(5 downto 4)<=A2_OUT(7 downto 6);


        -- Result, row by row (An = A2_OUT(n), Bn = B2_OUT(n)):
        --  row | A3_IN | B3_IN
        --   0  |  A0   |  A2
        --   1  |  A1   |  A3
        --   2  |  B0   |  B2
        --   3  |  B1   |  B3
        --   4  |  A4   |  A6
        --   5  |  A5   |  A7
        --   6  |  B4   |  B6
        --   7  |  B5   |  B7

    -- COLUMN 3: W^k with k = W_col3(i). Shift by 1.
    COL3 : for i in 7 downto 0 generate
            BUTTERFLY_col3: BUTTERFLY PORT MAP(
                RES    => RES,
                RES_SINC    => RES_SINC,
                CLK    => CLK,
                SF_2H_1L  => '0',
                START  => DONE2(i),
                DONE   => DONE3(i),
                x1_IN  => A3_IN(i),     -- A
                x2_IN  => B3_IN(i),     -- B
                WR     => WR(W_col3(i)),
                WI     => WI(W_col3(i)),
                X1_OUT => A3_OUT(i),
                X2_OUT => B3_OUT(i));
        END GENERATE COL3;

        -- Inputs of column 4, row by row (An = A3_OUT(n), Bn = B3_OUT(n)):
        --  row | A4_IN | B4_IN
        --   0  |  A0   |  A1
        --   1  |  B0   |  B1
        --   2  |  A2   |  A3
        --   3  |  B2   |  B3
        --   4  |  A4   |  A5
        --   5  |  B4   |  B5
        --   6  |  A6   |  A7
        --   7  |  B6   |  B7
    gen_input_col4 : process(A3_OUT,B3_OUT)
    BEGIN
        for i in 0 to 7 loop
             if((i mod 2) = 0) then
                -- even row: the two A' outputs of rows i and i+1
                A4_IN(i) <= A3_OUT(i);
                B4_IN(i) <= A3_OUT(i+1);
             else
                -- odd row: the two B' outputs of rows i-1 and i
                A4_IN(i) <= B3_OUT(i-1);
                B4_IN(i) <= B3_OUT(i);
             end if;
        end loop;
    END process gen_input_col4;

    -- COLUMN 4: W^k with k = W_col4(i). Shift by 1.
    COL4 : for i in 7 downto 0 generate
            BUTTERFLY_col4: BUTTERFLY PORT MAP(
                RES    => RES,
                RES_SINC    => RES_SINC,
                CLK    => CLK,
                SF_2H_1L  => '0',
                START  => DONE3(i),
                DONE   => DONE4(i),
                x1_IN  => A4_IN(i),     -- A
                x2_IN  => B4_IN(i),     -- B
                WR     => WR(W_col4(i)),
                WI     => WI(W_col4(i)),
                X1_OUT => A4_OUT(i),
                X2_OUT => B4_OUT(i));
        END GENERATE COL4;



        -- Outputs of column 4, row by row (bit-reversed order):
        --  row | A4_OUT | B4_OUT
        --   0  |  X0    |  X8
        --   1  |  X4    |  X12
        --   2  |  X2    |  X10
        --   3  |  X6    |  X14
        --   4  |  X1    |  X9
        --   5  |  X5    |  X13
        --   6  |  X3    |  X11
        --   7  |  X7    |  X15
        -- Here they are put back in natural order:

        X_OUT(0)<= A4_OUT(0);
        X_OUT(4)<= A4_OUT(1);
        X_OUT(2)<= A4_OUT(2);
        X_OUT(6)<= A4_OUT(3);
        X_OUT(1)<= A4_OUT(4);
        X_OUT(5)<= A4_OUT(5);
        X_OUT(3)<= A4_OUT(6);
        X_OUT(7)<= A4_OUT(7);
        X_OUT(8)<= B4_OUT(0);
        X_OUT(12)<= B4_OUT(1);
        X_OUT(10)<= B4_OUT(2);
        X_OUT(14)<= B4_OUT(3);
        X_OUT(9)<= B4_OUT(4);
        X_OUT(13)<= B4_OUT(5);
        X_OUT(11)<= B4_OUT(6);
        X_OUT(15)<= B4_OUT(7);

END Behavior;
