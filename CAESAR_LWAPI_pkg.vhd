------------------------------------------------------------------------------
--! @File        : CAESAR_LWAPI_pkg.vhd (CAESAR API for Lightweight)            
--! @Brief       : CAESAR lightweight API package                               
--!   ______   ________  _______    ______                                      
--!  /      \ /        |/       \  /      \                                     
--! /$$$$$$  |$$$$$$$$/ $$$$$$$  |/$$$$$$  |                                    
--! $$ |  $$/ $$ |__    $$ |__$$ |$$ | _$$/                                     
--! $$ |      $$    |   $$    $$< $$ |/    |                                    
--! $$ |   __ $$$$$/    $$$$$$$  |$$ |$$$$ |                                    
--! $$ \__/  |$$ |_____ $$ |  $$ |$$ \__$$ |                                    
--! $$    $$/ $$       |$$ |  $$ |$$    $$/                                     
--!  $$$$$$/  $$$$$$$$/ $$/   $$/  $$$$$$/                                      
--!                                                                             
--! @Author     : Panasayya Yalla & Ekawat (ice) Homsirikamol                   
--! @Copyright  : Copyright © 2016 Cryptographic Engineering Research Group     
--!                ECE Department, George Mason University Fairfax, VA, U.S.A.  
--!                All rights Reserved.                                         
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             —unrestricted)                                                  
--------------------------------------------------------------------------------
--! Description                                                                 
--!                                                                             
--!                                                                             
--!                                                                             
--!                                                                             
--!                                                                             
--!                                                                             
--------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.design_pkg.all;


package CAESAR_LWAPI_pkg is    
        
    ----INSTRUCTIONS (OPCODES)
    constant INST_ENC       : std_logic_vector(4    -1 downto 0):="0010";
    constant INST_DEC       : std_logic_vector(4    -1 downto 0):="0011";
    constant INST_LDKEY     : std_logic_vector(4    -1 downto 0):="0100";
    constant INST_ACTKEY    : std_logic_vector(4    -1 downto 0):="0111";
    constant INST_SUCCESS   : std_logic_vector(4    -1 downto 0):="1110";
    constant INST_FAILURE   : std_logic_vector(4    -1 downto 0):="1111";
    ----SEGMENT TYPE ENCODING
    ----Reserved                                                :="0000";
    constant HDR_AD         : std_logic_vector(4    -1 downto 0):="0001";
    constant HDR_NPUB_AD    : std_logic_vector(4    -1 downto 0):="0010";
    constant HDR_AD_NPUB    : std_logic_vector(4    -1 downto 0):="0011";
    constant HDR_MSG        : std_logic_vector(4    -1 downto 0):="0100";
    constant HDR_CT         : std_logic_vector(4    -1 downto 0):="0101";
    constant HDR_CT_TAG     : std_logic_vector(4    -1 downto 0):="0110";
    ----Reserved                                                :="0111";
    constant HDR_TAG        : std_logic_vector(4    -1 downto 0):="1000";
    ----Reserved                                                :="1001";
    constant Length         : std_logic_vector(4    -1 downto 0):="1010";
    ----Reserved                                                :="1011";
    constant HDR_KEY        : std_logic_vector(4    -1 downto 0):="1100";
    constant HDR_NPUB       : std_logic_vector(4    -1 downto 0):="1101";
    constant HDR_NSEC       : std_logic_vector(4    -1 downto 0):="1110";
    constant HDR_ENSEC      : std_logic_vector(4    -1 downto 0):="1111";
    ---Maximum supported length
    constant SINGLE_PASS_MAX: integer := 32;
    constant TWO_PASS_MAX   : integer := 11;                                              --! Length of segment header
    
    --! Other    
    constant CTR_SIZE_LIM   : integer := 16;                                            --! Limit to the segment counter size    

    --! Functions
    function maximum(a, b: integer) return integer;                                         --! Get maximum
    function nway_or( x : std_logic_vector) return std_logic;                               --! Or all bits of an input
    function get_words(size: integer; iowidth:integer) return integer;                      --! Calculate the number of I/O words for a particular size
    function get_width(size: integer; iowidth: integer) return integer;                     --! Calculate the width of register (used when not divisible by I/O size, i.e. NPUB = 96 with I/O = 64-bit) 
    function get_cntr_width(iowidth: integer) return integer;                               --! Calculate the length of size register (used when I/O size < counter limit size)
    function log2_ceil (N: natural) return natural;                                         --! Log(2) ceil
    function isNotDivisible(xx: integer; yy: integer) return integer;                          --! Determine a whether a value is divisible
        
end CAESAR_LWAPI_pkg;

package body CAESAR_LWAPI_pkg is
--! maximum
    function maximum(a, b: integer) return integer is
    begin
        if (a > b) then
            return a;
        else
            return b;
        end if;
    end function maximum;

    
    --! Or gate to all the input
    function nway_or( x : std_logic_vector) return std_logic is
        variable y : std_logic;
    begin
        y := x(0);
        for i in x'low+1 to x'high loop
            y := y or x(i);
        end loop;
        return y;
    end function nway_or;

    --! Calculate the number of words
    function get_words(size: integer; iowidth:integer) return integer is
    begin
        if (size mod iowidth) > 0 then
            return size/iowidth + 1;
        else
            return size/iowidth;
        end if;
    end function get_words;

    --! Calculate the expected width
    function get_width(size: integer; iowidth: integer) return integer is
    begin
        if (iowidth >= size) then
            return size;
        else
            return (size mod iowidth)+size;
        end if;
    end function get_width;

    --! Get the size of the public data
    function get_cntr_width(iowidth: integer) return integer is
    begin
        if iowidth-16 >= CTR_SIZE_LIM then
            return CTR_SIZE_LIM;
        else
            return iowidth-16;
        end if;
    end function get_cntr_width;

    --! Log of base 2
    function log2_ceil (N: natural) return natural is
    begin
         if ( N = 0 ) then
             return 0;
         elsif N <= 2 then
             return 1;
         else
            if (N mod 2 = 0) then
                return 1 + log2_ceil(N/2);
            else
                return 1 + log2_ceil((N+1)/2);
            end if;
         end if;
    end function log2_ceil;
    
    function isNotDivisible(xx: integer; yy: integer) return integer is
    begin
        if (xx MOD yy) /= 0 then
            return 1;
        else
            return 0;
        end if;
    end function isNotDivisible;
 
end CAESAR_LWAPI_pkg;
