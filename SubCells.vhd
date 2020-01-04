----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/02/2019 11:11:14 PM
-- Design Name: 
-- Module Name: SubCells - Behavioral
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
----------------------------------------------------------------
entity SubCells is
    Port(
        SubC_in     : in std_logic_vector(127 downto 0);
        SubC_out    : out std_logic_vector(127 downto 0)
    );
end SubCells;

-- Architecture
----------------------------------------------------------------
architecture Behavioral of SubCells is
    
    -- Signals -------------------------------------------------
    signal temp_in, temp_out    : std_logic_vector(127 downto 0); -- Every column of current and updated state
    
    -- Components ----------------------------------------------
    component Sbox is
        Port(
            Sb_in   : in std_logic_vector (3 downto 0);
            Sb_out  : out std_logic_vector (3 downto 0)
        );
    end component Sbox;
    
----------------------------------------------------------------
begin

    GEN_SB: for i in 31 downto 0 generate
        temp_in(4*i + 3 downto 4*i + 0) <= SubC_in(i) & SubC_in(32 + i) & SubC_in(64 + i) & SubC_in(96 + i); -- Sbox input: S3,S2,S1,S0
        SB: Sbox Port map(
            Sb_in  => temp_in(4*i + 3 downto 4*i + 0),
            Sb_out => temp_out(4*i + 3 downto 4*i + 0) -- Sbox output: S3,S2,S1,S0
            );
        SubC_out(96 + i) <= temp_out(4*i);
        SubC_out(64 + i) <= temp_out(4*i + 1);
        SubC_out(32 + i) <= temp_out(4*i + 2);
        SubC_out(i)      <= temp_out(4*i + 3);
    end generate GEN_SB;
    
end Behavioral;
