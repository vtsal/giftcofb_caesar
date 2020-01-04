--------------------------------------------------------------------------------
--! @File        : CipherCore.vhd
--! @Brief       : Template for Cipher core 
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
--! @Author      : Farnoud Farahmand and Panasayya Yalla
--! @Copyright   : Copyright © 2016 Cryptographic Engineering Research Group    
--!                ECE Department, George Mason University Fairfax, VA, U.S.A.  
--!                All rights Reserved.
--! @license    This project is released under the GNU Public License.          
--!             The license and distribution terms for this file may be         
--!             found in the file LICENSE in this distribution or at            
--!             http://www.gnu.org/licenses/gpl-3.0.txt                         
--! @note       This is publicly available encryption source code that falls    
--!             under the License Exception TSU (Technology and software-       
--!             -unrestricted)                                                  
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.design_pkg.all;

-- Entity
--------------------------------------------------------------------------------
entity CipherCore is
    Port ( 
            clk             : in   STD_LOGIC;
            rst             : in   STD_LOGIC;
            --PreProcessor===============================================
            ----!key----------------------------------------------------
            key             : in   STD_LOGIC_VECTOR (SW      -1 downto 0);
            key_valid       : in   STD_LOGIC;
            key_ready       : out  STD_LOGIC;
            ----!Data----------------------------------------------------
            bdi             : in   STD_LOGIC_VECTOR (W       -1 downto 0);
            bdi_valid       : in   STD_LOGIC;
            bdi_ready       : out  STD_LOGIC;
            bdi_partial     : in   STD_LOGIC;
            bdi_pad_loc     : in   STD_LOGIC_VECTOR (Wdiv8   -1 downto 0);
            bdi_valid_bytes : in   STD_LOGIC_VECTOR (Wdiv8   -1 downto 0);
            bdi_size        : in   STD_LOGIC_VECTOR (3       -1 downto 0);
            bdi_eot         : in   STD_LOGIC;
            bdi_eoi         : in   STD_LOGIC;
            bdi_type        : in   STD_LOGIC_VECTOR (4       -1 downto 0);
            decrypt_in      : in   STD_LOGIC;
            key_update      : in   STD_LOGIC;
            --!Post Processor=========================================
            bdo             : out  STD_LOGIC_VECTOR (W       -1 downto 0);
            bdo_valid       : out  STD_LOGIC;
            bdo_ready       : in   STD_LOGIC;
            --bdo_size        : out  STD_LOGIC_VECTOR (3 -1 downto 0);
            bdo_type        : out  STD_LOGIC_VECTOR (4       -1 downto 0);
            bdo_valid_bytes : out  STD_LOGIC_VECTOR (Wdiv8   -1 downto 0);
            end_of_block    : out  STD_LOGIC;
            decrypt_out     : out  STD_LOGIC;
            msg_auth        : out std_logic;
            msg_auth_valid  : out std_logic;
            msg_auth_ready  : in  std_logic
         );
            
end CipherCore;

-- Architecture
------------------------------------------------------------------------------
architecture structure of CipherCore is


------------------------------------------------------------------------------
begin

    MainCipher: entity work.GIFTCOFB
    Port map(
        clk             => clk,
        rst             => rst,
        -- Data Input
        key             => key,
        bdi             => bdi,
        -- Key Control
        key_valid       => key_valid,
        key_ready       => key_ready,
        key_update      => key_update,
        -- BDI Control
        bdi_valid       => bdi_valid,
        bdi_ready       => bdi_ready,
        bdi_partial     => bdi_partial,
        bdi_pad_loc     => bdi_pad_loc,
        bdi_valid_bytes => bdi_valid_bytes,
        bdi_size        => bdi_size,
        bdi_eot         => bdi_eot,
        bdi_eoi         => bdi_eoi,
        bdi_type        => bdi_type,
        decrypt_in      => decrypt_in,
        -- Data Output
        bdo             => bdo,
        -- BDO Control
        bdo_valid       => bdo_valid,
        bdo_ready       => bdo_ready,
        bdo_valid_bytes => bdo_valid_bytes,
        end_of_block    => end_of_block,
        bdo_type        => bdo_type,
        decrypt_out     => decrypt_out,
        -- Tag Verification
        msg_auth        => msg_auth,
        msg_auth_valid  => msg_auth_valid,
        msg_auth_ready  => msg_auth_ready 
    );

end structure;