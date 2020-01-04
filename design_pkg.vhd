------------------------------------------------------------------------------
--! @File        : Design_pkg.vhd (Design package for Lightweight)            
--! @Brief       : Design pkg file where the generics for LW are set                             
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
--! @Copyright  : Copyright © 2017 Cryptographic Engineering Research Group     
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


package Design_pkg is
    --==========================================================================
    --! I/O parameters
    ----------------------------------------------------------------------------
    constant PW              : integer := 32;
    constant SW              : integer := 32;
    constant W               : integer := 32;
    constant PWdiv8          : integer := PW/8;
    constant SWdiv8          : integer := SW/8;
    constant Wdiv8           : integer := PW/8;
    constant LSBYTES         : integer := PW/8+1;---log2(w/8);
    --==========================================================================

    
    --==========================================================================
    --! Design parameters
    constant G_DBLK_SIZE     : integer := 128;   --! Data
    constant G_KEY_SIZE      : integer := 128;   --! Key
    constant G_TAG_SIZE      : integer := 128;   --! Tag
    --==========================================================================
    
    --==========================================================================
    --! TAG VERIFICAITON SETTING
    ----------------------------------------------------------------------------
    ----False --> Performed externally in the PostProcessor. Hence, tag is 
    ----          passed into CipherCore
    ----True  --> Performed internally within the CipherCore
    constant TAG_INTERNAL   : boolean := True;
    --==========================================================================
    
    --==========================================================================
    --! Async active low reset
    ----------------------------------------------------------------------------
    ----TRUE   --> NOT YET SUPPORTED!!!
    ----FALSE  --> Active-high synchronous reset
    constant ASYNC_RSTN    : boolean := False;
    --==========================================================================
end Design_pkg;
