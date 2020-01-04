----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05/30/2019 06:09:48 PM
-- Design Name: 
-- Module Name: Sbox - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- Entity
------------------------------------------------------------
entity Sbox is
  Port (Sb_in   : in std_logic_vector (3 downto 0);
        Sb_out  : out std_logic_vector (3 downto 0));
end Sbox;

-- Architecture
------------------------------------------------------------
architecture Behavioral of Sbox is

    -- Signals ---------------------------------------------
    signal S0, S1, S2, S3, S11, S22, S33    : std_logic;

------------------------------------------------------------  
begin

    S1      <= Sb_in(1) xor (Sb_in(0) and Sb_in(2));
    S0      <= Sb_in(0) xor (S1 and Sb_in(3));
    S2      <= Sb_in(2) xor (S0 or S1);
    S3      <= Sb_in(3) xor S2;
    S11     <= S1 xor S3;
    S33     <= not S3;
    S22     <= S2 xor (S0 and S11);
    Sb_out  <= S0 & S22 & S11 & S33; -- 4-bit Sbox

end Behavioral;
