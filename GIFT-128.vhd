----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/30/2019 05:17:50 PM
-- Design Name: 
-- Module Name: GIFT-128 - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- Entity
------------------------------------------------------------------------
entity GIFT128 is
    Port (
        clk         : in std_logic;
        rst         : in std_logic;
        start       : in std_logic;
        Key         : in std_logic_vector (127 downto 0);
        X_in        : in std_logic_vector (127 downto 0);
        Y_out       : out std_logic_vector (127 downto 0);
        done        : out std_logic
    );
end GIFT128;

-- Architecture
-----------------------------------------------------------------------
architecture Behavioral of GIFT128 is

    -- Signals ---------------------------------------------------------
    signal S0, S1, S2, S3                   : std_logic_vector(31 downto 0); -- Four 32-bit words of current state
    signal S0_Up, S1_Up, S2_Up, S3_Up       : std_logic_vector(31 downto 0); -- Four 32-bit words of updated state 
    signal W0, W1, W2, W3, W4, W5, W6, W7   : std_logic_vector(15 downto 0); -- Eight 16-bit segments of key state
    signal U, V                             : std_logic_vector(31 downto 0); -- Round key: RK = U || V
    signal SubC_temp                        : std_logic_vector(127 downto 0); -- As the input of SubCells (just because in a port map no functions should be used)
    signal state_Sub, state_Permu           : std_logic_vector(127 downto 0); -- 128-bit satate after substitusion and permutation layers
    signal state_Up, Kstate_Up              : std_logic_vector(127 downto 0); -- 128-bit updated state and key state
    signal round_Num                        : natural range 0 to 39; -- Round number
    signal round_Cons                       : std_logic_vector(5 downto 0); -- 6-bit LFSR round constant
    signal RC_rst                           : std_logic; -- Reset for round constant generator(LFSR)
    
    -- Components ------------------------------------------------------
    component SubCells is
        Port(
            SubC_in     : in std_logic_vector(127 downto 0);
            SubC_out    : out std_logic_vector(127 downto 0)
        );
    end component SubCells;
    
    component PermBits is
        Port(
            P_in    : in std_logic_vector (127 downto 0);
            P_out   : out std_logic_vector (127 downto 0)
        );
    end component PermBits;
    
    component ConsGen is
        Port(
        clk         : in std_logic;
        rst         : in std_logic;
        round_Cons  : out std_logic_vector(5 downto 0)
    );
    end component ConsGen;
    
-------------------------------------------------------------------------   
begin

    -- Load 128-bit plaintext or updated state
    S0 <= X_in(127 downto 96) when (round_Num = 0) else state_Up(127 downto 96);
    S1 <= X_in(95 downto 64)  when (round_Num = 0) else state_Up(95 downto 64);
    S2 <= X_in(63 downto 32)  when (round_Num = 0) else state_Up(63 downto 32);
    S3 <= X_in(31 downto 0)   when (round_Num = 0) else state_Up(31 downto 0);
    
    -- Key schedule: Load 128-bit secret key or updated key state
    W0 <= Key(127 downto 112)   when (round_Num = 0) else Kstate_Up(17 downto 16) & Kstate_Up(31 downto 18);
    W1 <= Key(111 downto 96)    when (round_Num = 0) else Kstate_Up(11 downto 0) & Kstate_Up(15 downto 12);
    W2 <= Key(95 downto 80)     when (round_Num = 0) else Kstate_Up(127 downto 112);
    W3 <= Key(79 downto 64)     when (round_Num = 0) else Kstate_Up(111 downto 96);
    W4 <= Key(63 downto 48)     when (round_Num = 0) else Kstate_Up(95 downto 80);
    W5 <= Key(47 downto 32)     when (round_Num = 0) else Kstate_Up(79 downto 64);
    W6 <= Key(31 downto 16)     when (round_Num = 0) else Kstate_Up(63 downto 48);
    W7 <= Key(15 downto 0)      when (round_Num = 0) else Kstate_Up(47 downto 32);

    -- Round function --------------------------------------------------
    -- SubCells
    SubC_temp <= S0 & S1 & S2 & S3;
    SC: SubCells 
    Port map(
        SubC_in  => SubC_temp,
        SubC_out => state_Sub
    );
        
    --PermBits
    PB: PermBits 
    Port map(
        P_in  => state_Sub,
        P_out => state_Permu
    );

    -- Add round key and add round constant
    RC_rst <= '1' when (rst = '1' or start = '0' or round_Num = 39) else '0';
    RC: ConsGen
    Port map(
        clk         => clk,
        rst         => RC_rst,
        round_Cons  => round_Cons
    );
            
    U     <= W2 & W3;
    V     <= W6 & W7;
    S0_Up <= state_Permu(127 downto 96);
    S2_Up <= state_Permu(63 downto 32) xor U;  -- S2 xor U
    S1_Up <= state_Permu(95 downto 64) xor V; -- S1 xor V
    S3_Up <= state_Permu(31 downto 0) xor (x"800000" & "00" & round_Cons); -- S3 xor constant
   
   -- Process (one round per clock cycle)
    RF: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1' or start = '0') then
                round_Num   <= 0;
                done        <= '0';
--                Y_out       <= (others => '0');
            elsif (rst = '0' and start = '1') then
                round_Num   <= round_Num + 1;
                state_Up    <= S0_Up & S1_Up & S2_Up & S3_Up;
                Kstate_Up   <= W0 &  W1 &  W2 &  W3 &  W4 &  W5 &  W6 &  W7;
                case round_Num is
                    when 39 => 
                        round_Num               <= 0;
                        done                    <= '1';
                        Y_out(127 downto 96)    <= S0_Up;
                        Y_out(95 downto 64)     <= S1_Up;
                        Y_out(63 downto 32)     <= S2_Up;
                        Y_out(31 downto 0)      <= S3_Up;
                    when others =>
                        done <= '0';
--                        Y_out <= (others => '0');
                end case;
            end if;
        end if;
    end process RF;

end Behavioral;
