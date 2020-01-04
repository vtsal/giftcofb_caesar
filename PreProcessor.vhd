--------------------------------------------------------------------------------
--! @File        : PreProcessor.vhd
--! @Brief       : Pre Processor for CAESWAR LW API
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
--! @Author      : Panasayya Yalla
--! @Copyright   : Copyright © 2016 Cryptographic Engineering Research Group    
--!                ECE Department, George Mason University Fairfax, VA, U.S.A.  
--!                All rights Reserved.
---! @license    This project is released under the GNU Public License.          
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";
use work.GeneralComponents_pkg.ALL;
use work.design_pkg.all;
use work.CAESAR_LWAPI_pkg.all;


entity PreProcessor is
    port (  --=====================================================
            --!EXTERNAL SIGNALS
            --=====================================================
            --!GLOBAL SIGNALS
            clk             : in STD_LOGIC;
            rst             : in STD_LOGIC;
            --!Public Data signals
            pdi_data        : in  STD_LOGIC_VECTOR(PW    -1 downto 0);
            pdi_valid       : in  STD_LOGIC;  
            pdi_ready       : out STD_LOGIC;  
            --!Secret Data signals
            sdi_data        : in  STD_LOGIC_VECTOR(SW    -1 downto 0);
            sdi_valid       : in  STD_LOGIC;  
            sdi_ready       : out STD_LOGIC;  
            --========================================================
            --!INTERNAL SIGNALS
            ----------------------------------------------------------
            ---!KEY PISO
            key             : out STD_LOGIC_VECTOR(SW    -1 downto 0);
            key_valid       : out STD_LOGIC;  
            key_ready       : in  STD_LOGIC;  
            ---!DATA PISO         
            bdi             : out STD_LOGIC_VECTOR(PW    -1 downto 0);
            bdi_valid       : out STD_LOGIC;
            bdi_ready       : in  STD_LOGIC;
            ----------------    
            bdi_partial     : out STD_LOGIC;
            bdi_pad_loc     : out STD_LOGIC_VECTOR(PWdiv8 -1 downto 0);
            bdi_valid_bytes : out STD_LOGIC_VECTOR(PWdiv8 -1 downto 0);
            ----------------
            bdi_size        : out STD_LOGIC_VECTOR(3     -1 downto 0);
            bdi_eot         : out STD_LOGIC;
            bdi_eoi         : out STD_LOGIC;
            bdi_type        : out STD_LOGIC_VECTOR(4    -1 downto 0);
            decrypt         : out STD_LOGIC;
            key_update      : out STD_LOGIC;
            ---!HEADER/TAG FIFO
            cmd             : out STD_LOGIC_VECTOR(PW    -1 downto 0);
            cmd_valid       : out STD_LOGIC;
            cmd_ready       : in  STD_LOGIC
        );
end entity PreProcessor;

architecture PreProcessor of PreProcessor is
---COUNTERS
    signal len_SegLenCnt : std_logic;
    signal en_SegLenCnt  : std_logic;
    signal last_segment  : std_logic;
    signal dout_SegLenCnt: std_logic_vector(16  -1 downto 0); 
    signal load_SegLenCnt: std_logic_vector(16  -1 downto 0); 
            
---REGISTERS
    signal en_LenReg  : std_logic;
    signal din_LenReg : std_logic_vector(8  -1 downto 0);
    signal dout_LenReg : std_logic_vector(8  -1 downto 0);
    signal dout_mlen1 : std_logic_vector(PW  -1 downto 0);
   
---FLAGS
--multiplexers
--controller
    signal bdi_last          : std_logic;
    signal decrypt_internal  : std_logic;
    signal sel_mlen1         : std_logic;
    signal ena_HDRFlagsReg   : std_logic;
    signal flags_valid       : std_logic;
    signal bdi_eoi_internal  : std_logic;
    signal bdi_eot_internal  : std_logic;
    signal bdi_size_not_last : std_logic_vector(2 downto 0);
    signal dout_HDRFlagsReg  : std_logic_vector(1 downto 0);
    signal ena_modereg       : std_logic;
    signal bdi_valid_bytes1  : STD_LOGIC_VECTOR(4   -1 downto 0);
    signal bdi_pad_loc1      : STD_LOGIC_VECTOR(4   -1 downto 0);
    constant  NumOfSeg       : integer:=integer(ceil(log2(real(PW))));
    constant zero_data       : STD_LOGIC_VECTOR(PW-1 downto 0):=(others=>'0');
    ---STATES
    type t_state is (S_INIT, 
                     ---KEY
                     S_INT_KEY,  S_HDR_KEY, S_HDR_KEYLEN, S_HDR_RESKEY, 
                     S_HDR_KEYLEN_MSB, S_HDR_KEYLEN_LSB, S_LD_KEY,
                     ---MODE
                     S_INT_MODE,
                     ---NPUB
                     S_HDR_NPUB, S_HDR_NPUBLEN, S_HDR_RESNPUB, 
                     S_HDR_NPUBLEN_MSB, S_HDR_NPUBLEN_LSB, S_LD_NPUB,
                     ---AD
                     S_HDR_AD, S_HDR_ADLEN, S_HDR_RESAD, 
                     S_HDR_ADLEN_MSB, S_HDR_ADLEN_LSB, S_LD_AD,
                     --MSG
                     S_HDR_MSG, S_HDR_MSGLEN, S_HDR_RESMSG, 
                     S_HDR_MSGLEN_MSB, S_HDR_MSGLEN_LSB, S_LD_MSG,
                     --TAG
                     S_HDR_TAG, S_HDR_TAGLEN, S_HDR_RESTAG, 
                     S_HDR_TAGLEN_MSB, S_HDR_TAGLEN_LSB, S_LD_TAG,
                     -- 
                     S_WAIT
                     );
    signal nx_state, pr_state:t_state;
    
begin
    
    --!======================
    --!SEGMENT LENGTH 
    --=======================
    
    SegLen:     StepDownCountLd 
                generic map(
                        N       =>  16,
                        step    =>  PWdiv8 
                            )
                port map
                        (
                        clk     =>  clk ,
                        len     =>  len_SegLenCnt,
                        load    =>  load_SegLenCnt,
                        ena     =>  en_SegLenCnt,
                        count   =>  dout_SegLenCnt
                    );
    ---checking for last segment if the length is less than 
    last_segment    <= '1' when (to_integer(unsigned(dout_SegLenCnt))<=PWdiv8) else '0';
    bdi_size        <= dout_SegLenCnt(2 downto 0) when last_segment='1' else bdi_size_not_last;      
    with PWdiv8 select 
    bdi_size_not_last <= "100" when 4,
                         "010" when 2,
                         "001" when 1,
                         "000" when others;
    with (to_integer(unsigned(dout_SegLenCnt))) select
    bdi_valid_bytes1<= "1110" when 3,
                       "1100" when 2,
                       "1000" when 1,
                       "0000" when 0,
                       --"1111" when 4,
                       "1111" when others;
    with (to_integer(unsigned(dout_SegLenCnt))) select                       
    bdi_pad_loc1    <= "0001" when 3,
                       "0010" when 2,
                       "0100" when 1,
                       "1000" when 0,
                       ---"0000" when 4,
                       "0000" when others;
        
    bdi_pad_loc    (PWdiv8 -1 downto 0) <= bdi_pad_loc1(3 downto 4-PWdiv8);
    bdi_valid_bytes(PWdiv8 -1 downto 0) <= bdi_valid_bytes1(3 downto 4-PWdiv8);    
    dout_mlen1                      <= sdi_data when sel_mlen1='1' else pdi_data;
    
    
    
    seg_8bit:
    if(PW=8) generate
    LenReg:     RegN
                generic map (
                        N                 => 8
                            )
                port map (
                        clk               => clk,
                        ena               => en_LenReg,
                        din               => dout_mlen1(PW-1 downto PW-8),
                        dout              => dout_LenReg
                        );    
    load_SegLenCnt <= dout_LenReg(7 downto 0) & dout_mlen1(PW-1 downto PW-8);
                      
    end generate;
    
    seg_16bit:
    if(PW=16) generate
    load_SegLenCnt <= dout_mlen1(PW-1 downto PW-8*PWdiv8);
    end generate;
    
    seg_32bit:
    if(PW=32) generate
    load_SegLenCnt <= dout_mlen1(PW-1-4*PWdiv8 downto 0);
    end generate;                  
    --==========================================================================
    --!Preserving the Header info bits(EOT, EOI, Last, Segment Type)
    --==========================================================================
    HDRFlags:   RegN
                generic map (
                        N   => 2
                    )
                port map (
                        clk               => clk,
                        ena               => ena_HDRFlagsReg,
                        din               => pdi_data(PW-6 downto PW-7),
                        dout              => dout_HDRFlagsReg
                        );
    bdi_eoi_internal  <= dout_HDRFlagsReg(1) and last_segment and flags_valid;                        
    bdi_eot_internal  <= dout_HDRFlagsReg(0) and last_segment and flags_valid;
    bdi_eoi           <= bdi_eoi_internal;
    bdi_eot           <= bdi_eot_internal;
    
    ---bdi_last <= dout_HDRFlagsReg(0);
    ModeReg:    Reg                       
                port map(                 
                        clk               => clk,
                        ena               => ena_ModeReg,
                        din               => pdi_data(PW-4),
                        dout              => decrypt_internal
                        );
    decrypt<=decrypt_internal;                        
    --==========================================================================
    ---!Assigning Data to buses
    cmd <= pdi_data;
    bdi <= pdi_data;
    key <= sdi_data; 
    
    
    
    --!FSM FOR PREPROCESSOR
    --=====STATE REGISTER=======================================================
    process (clk,rst)
    begin
        if(rst='1')  then
            pr_state <= S_INT_MODE;
        elsif rising_edge(clk) then
            pr_state <= nx_state;
        end if;
    end process;
    --==========================================================================    
    --!next state function
    --==========================================================================
    
    process (pr_state,sdi_valid,pdi_valid,sdi_data,pdi_data,last_segment,decrypt_internal,
             key_ready,bdi_ready,cmd_ready,dout_hdrflagsreg,bdi_eot_internal,dout_lenreg,
             bdi_eoi_internal)
    
    begin
        case pr_state is
            
            when S_INIT=>
                    nx_state <= S_INT_MODE;
                


            ---MODE SET---------------------------------------------------
                     
            when S_INT_MODE=> 
                if(pdi_valid='1') then 
                    if(pdi_data(PW-1 downto PW-4)=INST_ACTKEY)then
                        nx_state<= S_INT_KEY;
                    elsif(pdi_data(PW-1 downto PW-3)=INST_ENC(3 downto 1))then
                        nx_state <= S_HDR_NPUB;
                    else
                        nx_state <=S_INT_MODE;
                    end if;
                else
                    nx_state <= S_INT_MODE;
                end if;
            ---load key----------------------------------------------------
            when S_INT_KEY=>
                if(sdi_valid='1' and sdi_data(PW-1 downto PW-4)=INST_LDKEY) then
                    nx_state <= S_HDR_KEY;
                else
                    nx_state<= S_INT_KEY;
                end if;
            
            
            when S_HDR_KEY=>
                if(sdi_valid='1' and sdi_data(PW-1 downto PW-4)=HDR_KEY) then
                    if(PWdiv8=1)then
                        nx_state <= S_HDR_RESKEY;
                    elsif(PWdiv8=2)then
                        nx_state  <= S_HDR_KEYLEN;
                    else    
                        nx_state  <= S_LD_KEY;
                    end if;
                else
                    nx_state <= S_HDR_KEY;
                end if;
            
            when S_HDR_RESKEY=>
                if(sdi_valid='1') then
                    nx_state <= S_HDR_KEYLEN_MSB;
                else
                    nx_state <= S_HDR_RESKEY;
                end if;
            
            when S_HDR_KEYLEN_MSB=>
                if(sdi_valid='1') then
                    nx_state <= S_HDR_KEYLEN_LSB;
                else
                    nx_state <= S_HDR_KEYLEN_MSB;
                end if;
                        
            when S_HDR_KEYLEN_LSB=>
                if(sdi_valid='1') then
                    nx_state <= S_LD_KEY;
                else
                    nx_state <= S_HDR_KEYLEN_LSB;
                end if;
            
            when S_HDR_KEYLEN=>
                if(sdi_valid='1') then
                    nx_state <= S_LD_KEY;
                else
                    nx_state <= S_HDR_KEYLEN;
                end if;
            
            when S_LD_KEY=>            
                if(sdi_valid='1' and key_ready='1' and last_segment='1') then
                    nx_state <= S_INT_MODE;
                else
                    nx_state <= S_LD_KEY;
                end if;
            ---NPUB    
            
            when S_HDR_NPUB=>
                if(pdi_valid='1' and pdi_data(PW-1 downto PW-4)=HDR_NPUB) then
                    if(PWdiv8=1)then
                        nx_state <= S_HDR_RESNPUB;
                    elsif(PWdiv8=2)then
                        nx_state  <= S_HDR_NPUBLEN;
                    else    
                        nx_state  <= S_LD_NPUB;
                    end if;
                else
                    nx_state <= S_HDR_NPUB;
                end if;
            
            when S_HDR_RESNPUB=>
                if(pdi_valid='1') then
                    nx_state <= S_HDR_NPUBLEN_MSB;
                else
                    nx_state <= S_HDR_RESNPUB;
                end if;
            
            when S_HDR_NPUBLEN_MSB=>
                if(pdi_valid='1') then
                    nx_state <= S_HDR_NPUBLEN_LSB;
                else
                    nx_state <= S_HDR_NPUBLEN_MSB;
                end if;
                        
            when S_HDR_NPUBLEN_LSB=>
                if(pdi_valid='1') then
                    nx_state <= S_LD_NPUB;
                else
                    nx_state <= S_HDR_NPUBLEN_LSB;
                end if;
            
            when S_HDR_NPUBLEN=>
                if(pdi_valid='1') then
                    nx_state <= S_LD_NPUB;
                else
                    nx_state <= S_HDR_NPUBLEN;
                end if;
            
            when S_LD_NPUB =>            
                if(pdi_valid='1' and bdi_ready='1' and last_segment='1')then
                    nx_state <= S_HDR_AD;
                   
                else
                    nx_state <= S_LD_NPUB;
                end if;
                    
            --AD
            when S_HDR_AD=>
                if(pdi_valid='1' and pdi_data(PW-1 downto PW-4)=HDR_AD) then
                    if(PWdiv8=1)then
                        nx_state <= S_HDR_RESAD;
                    elsif(PWdiv8=2)then
                        nx_state  <= S_HDR_ADLEN;
                    else
                        if(pdi_data(15 downto 0)=x"0000" and dout_HDRFlagsReg(0)='1')then
                            nx_state<=S_HDR_MSG;
                        else    
                            nx_state  <= S_LD_AD;
                        end if;
                    end if;
                else
                    nx_state <= S_HDR_AD;
                end if;
            
            when S_HDR_RESAD=>
                if(pdi_valid='1') then
                    nx_state <= S_HDR_ADLEN_MSB;
                else
                    nx_state <= S_HDR_RESAD;
                end if;
            
            when S_HDR_ADLEN_MSB=>
                if(pdi_valid='1') then
                    nx_state <= S_HDR_ADLEN_LSB;
                else
                    nx_state <= S_HDR_ADLEN_MSB;
                end if;
                        
            when S_HDR_ADLEN_LSB=>
                if(pdi_valid='1') then
                    if(dout_LenReg=x"00" and pdi_data(7 downto 0)=x"00" and dout_HDRFlagsReg(0)='1')then
                        if(bdi_eoi_internal='1')then
                            if(decrypt_internal='1')then
                                nx_state  <= S_WAIT;
                            else
                                nx_state  <= S_HDR_TAG;
                            end if;
                        else
                            nx_state<=S_HDR_MSG;
                        end if;
                    else    
                        nx_state <= S_LD_AD;
                    end if;    
                else
                    nx_state <= S_HDR_ADLEN_LSB;
                end if;
            
            when S_HDR_ADLEN=>
                if(pdi_valid='1') then
                    if(pdi_data= zero_data and dout_HDRFlagsReg(0)='1')then
                        if(bdi_eoi_internal='1')then
                            if(decrypt_internal='1')then
                                nx_state  <= S_HDR_TAG;
                            else
                                nx_state  <= S_WAIT;
                            end if;
                        else
                            nx_state<=S_HDR_MSG;
                        end if;
                    else    
                        nx_state <= S_LD_AD;
                    end if;
                else
                    nx_state <= S_HDR_ADLEN;
                end if;
            
            when S_LD_AD =>           
                if(pdi_valid='1' and bdi_ready='1' and last_segment='1')then 
                    if(dout_HDRFlagsReg(0)='1') then--eot
                        nx_state <= S_HDR_MSG;
                    else
                        nx_state <= S_HDR_AD;
                    end if;
                else    
                    nx_state <= S_LD_AD;
                end if;
                    
            --MSG OR CIPHER TEXT
            when S_HDR_MSG=>
                if(pdi_valid='1' and pdi_data(PW-1 downto PW-3)=HDR_MSG(3 downto 1))then
                    if(PWdiv8=1)then
                        nx_state <= S_HDR_RESMSG;
                    elsif(PWdiv8=2)then
                        nx_state  <= S_HDR_MSGLEN;
                    else
                        if(pdi_data(15 downto 0)=x"0000" and dout_HDRFlagsReg(0)='1')then
                            if(decrypt_internal='1')then
                                nx_state  <= S_HDR_TAG;
                            else    
                                nx_state<= S_WAIT;
                            end if;
                        else
                            nx_state  <= S_LD_MSG;
                        end if;
                    end if;
                else
                    nx_state <= S_HDR_MSG;
                end if;
            
            when S_HDR_RESMSG=>
                if(pdi_valid='1' and cmd_ready='1') then
                    nx_state <= S_HDR_MSGLEN_MSB;
                else
                    nx_state <= S_HDR_RESMSG;
                end if;
            
            when S_HDR_MSGLEN_MSB=>
                if(pdi_valid='1'and cmd_ready='1') then
                    nx_state <= S_HDR_MSGLEN_LSB;
                else
                    nx_state <= S_HDR_MSGLEN_MSB;
                end if;
                        
            when S_HDR_MSGLEN_LSB=>
                if(pdi_valid='1'and cmd_ready='1') then
                    if(dout_LenReg=x"00" and pdi_data(7 downto 0)=x"00" and dout_HDRFlagsReg(0)='1')then
                        if(decrypt_internal='1')then
                            nx_state  <= S_HDR_TAG;
                        else
                            nx_state  <= S_WAIT;
                        end if;
                    else    
                        nx_state <= S_LD_MSG;
                    end if;
                else
                    nx_state <= S_HDR_MSGLEN_LSB;
                end if;
            
            when S_HDR_MSGLEN=>
                if(pdi_valid='1'and cmd_ready='1') then
                    if(pdi_data=zero_data and dout_HDRFlagsReg(0)='1')then
                        if(decrypt_internal='1')then
                            nx_state  <= S_HDR_TAG;
                        else
                            nx_state  <= S_WAIT;
                        end if;
                    else
                        nx_state<=S_LD_MSG;
                    end if;
                else
                    nx_state <= S_HDR_MSGLEN;
                end if;
            
            when S_LD_MSG =>           
                if(pdi_valid='1' and bdi_ready='1' and last_segment='1') then
                    if(dout_HDRFlagsReg(0)='1') then
                        if(decrypt_internal='1')then
                            nx_state <= S_HDR_TAG;
                        else
                            nx_state <= S_WAIT;
                            --nx_state <= S_HDR_TAG;
                        end if;
                    else
                        nx_state <= S_HDR_MSG;
                    end if;
                else
                    nx_state <= S_LD_MSG;
                end if;
            
            
            --TAG
            
            when S_HDR_TAG=>
                if(pdi_valid='1' and pdi_data(PW-1 downto PW-4)=HDR_TAG) then
                    if(PWdiv8=1)then
                        nx_state <= S_HDR_RESTAG;
                    elsif(PWdiv8=2)then
                        nx_state  <= S_HDR_TAGLEN;
                    else
                        nx_state <= S_LD_TAG;
                    end if;
                else
                    nx_state <= S_HDR_TAG;
                end if;
            
            when S_HDR_RESTAG=>
                if(pdi_valid='1') then
                    nx_state <= S_HDR_TAGLEN_MSB;
                else
                    nx_state <= S_HDR_RESTAG;
                end if;
            
            when S_HDR_TAGLEN_MSB=>
                if(pdi_valid='1') then
                    nx_state <= S_HDR_TAGLEN_LSB;
                else
                    nx_state <= S_HDR_TAGLEN_MSB;
                end if;
                        
            when S_HDR_TAGLEN_LSB=>
                if(pdi_valid='1') then
                    nx_state <= S_LD_TAG;
                else
                    nx_state <= S_HDR_TAGLEN_LSB;
                end if;
            
            when S_HDR_TAGLEN=>
                if(pdi_valid='1') then
                    nx_state <= S_LD_TAG;
                else
                    nx_state <= S_HDR_TAGLEN;
                end if;
            
            when S_LD_TAG =>           
                if(pdi_valid='1' and last_segment='1') then
                    if(TAG_INTERNAL)then --- if true, load tag into ciphercore
                        if(bdi_ready='1' ) then
                            nx_state <= S_INT_MODE;
                        else
                            nx_state <= S_LD_TAG;
                        end if;
                    else
                        if(cmd_ready='1') then
                            nx_state <= S_INT_MODE;
                        else
                            nx_state <= S_LD_TAG;
                        end if;
                    end if;
                else
                    nx_state <= S_LD_TAG;
                end if;
            
                
            when S_WAIT=>
                if(pdi_valid='1' or sdi_valid='1') then 
                    nx_state <= S_INT_MODE;
                else
                    nx_state <= S_WAIT;
                end if;
                
            
            when others=>
                nx_state <= S_INIT;
            
        end case;
    end process;
    --==========================================================================    
    --!output state function
    --==========================================================================        
    process(pr_state,sdi_valid, pdi_valid, 
            key_ready, bdi_ready, cmd_ready,pdi_data,decrypt_internal)
            
            
    begin  
            --DEFAULT SIGNALS
            --external interface
            sdi_ready   <='0';
            pdi_ready   <='0';
            --Ciphercore
            key_valid   <='0';
            bdi_valid   <='0';
            bdi_type    <="0000";
            bdi_partial <='0';
            flags_valid <='0';---eot, eoi flags
            
            ---header/tag-FIFO
            cmd_valid   <='0';
            ---internal
            -----counters
            len_SegLenCnt<='0';
            en_SegLenCnt <='0';
            -----register
            en_LenReg   <= '0';
            sel_mlen1   <= '0';
            ena_HDRFlagsReg<='0';
            ena_ModeReg <='0';
            ----
            key_update<='0';
            
        case pr_state is

            when S_INIT           => 
            ---KEY                
            ---MODE               
            when S_INT_MODE       =>
                pdi_ready       <= '1';
                if(pdi_data(PW-1 downto PW-3)=INST_ENC(3 downto 1))then
                    ena_ModeReg     <= pdi_valid;
                    cmd_valid       <= pdi_valid;
                    --pdi_ready       <= cmd_ready;
                end if;
            
            when S_INT_KEY        =>  
                sdi_ready       <='1';
                key_update      <='0';
            
            when S_HDR_KEY        => 
                sdi_ready       <='1';
                len_SegLenCnt   <= sdi_valid;
                sel_mlen1       <= '1';
                ena_HDRFlagsReg <=sdi_valid;
                
                
            when S_HDR_KEYLEN     => 
                sdi_ready       <='1';
                len_SegLenCnt   <= sdi_valid;
                sel_mlen1       <= '1';
            
            when S_HDR_RESKEY     => 
                sdi_ready       <='1';
                sel_mlen1       <= '1';
                
            when S_HDR_KEYLEN_MSB => 
                sdi_ready       <='1';
                sel_mlen1       <= '1';
                en_LenReg       <= sdi_valid;
                
            when S_HDR_KEYLEN_LSB =>
            
                sdi_ready       <='1';
                len_SegLenCnt   <= sdi_valid;
                sel_mlen1       <= '1';
            
            
            when S_LD_KEY         =>
                sdi_ready       <= key_ready;
                key_valid       <= sdi_valid;
                key_update      <= '1';
                en_SegLenCnt    <= sdi_valid and key_ready;
                flags_valid     <='1';
                
            ---NPUB               
            
            when S_HDR_NPUB       => 
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid;
                ena_HDRFlagsReg <= pdi_valid;
                
            when S_HDR_NPUBLEN    => 
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid;
                
            
            when S_HDR_RESNPUB    => 
                pdi_ready       <='1';
                
            when S_HDR_NPUBLEN_MSB=> 
                pdi_ready       <='1';
                en_LenReg       <= pdi_valid;
            
            when S_HDR_NPUBLEN_LSB=>
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid;
            
            when S_LD_NPUB        =>
                pdi_ready       <= bdi_ready;
                bdi_valid       <= pdi_valid;
                bdi_type        <= HDR_NPUB;
                en_SegLenCnt    <= pdi_valid and bdi_ready;
                flags_valid     <='1';
            
            ---AD                 
            
            when S_HDR_AD         => 
                 pdi_ready      <='1';
                 len_SegLenCnt  <= pdi_valid;
                 ena_HDRFlagsReg<=pdi_valid;
            
            when S_HDR_ADLEN      => 
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid;
            
            when S_HDR_RESAD      => 
                pdi_ready       <='1';
            
            when S_HDR_ADLEN_MSB  => 
                pdi_ready       <='1';
                en_LenReg       <= pdi_valid;
            
            when S_HDR_ADLEN_LSB  => 
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid;
            
            when S_LD_AD          =>
                pdi_ready       <= bdi_ready;
                bdi_valid       <= pdi_valid;
                bdi_type        <= HDR_AD;
                en_SegLenCnt    <= pdi_valid and bdi_ready;
                flags_valid     <='1';
            
            --MSG                 
            
            when S_HDR_MSG        =>
                if(pdi_data(PW-1 downto PW-3)=HDR_MSG(3 downto 1))then
                    cmd_valid    <=pdi_valid;
                end if;
                pdi_ready       <=cmd_ready;
                len_SegLenCnt   <= pdi_valid and cmd_ready;
                ena_HDRFlagsReg <=pdi_valid and cmd_ready;
            
            when S_HDR_MSGLEN     =>
                pdi_ready       <=cmd_ready;
                cmd_valid       <=pdi_valid;
                len_SegLenCnt   <= pdi_valid and cmd_ready;
            
            
            when S_HDR_RESMSG     =>
                pdi_ready       <=cmd_ready;
                cmd_valid       <=pdi_valid;
            
            when S_HDR_MSGLEN_MSB => 
                pdi_ready       <=cmd_ready;
                en_LenReg       <= pdi_valid and cmd_ready;
                cmd_valid       <=pdi_valid;
            
            when S_HDR_MSGLEN_LSB =>
                pdi_ready       <= cmd_ready;
                len_SegLenCnt   <= pdi_valid and cmd_ready;
                cmd_valid       <= pdi_valid;
                
            
            when S_LD_MSG         =>
                pdi_ready       <= bdi_ready;
                bdi_valid       <= pdi_valid;
                bdi_type        <= HDR_MSG;
                en_SegLenCnt    <= pdi_valid and bdi_ready;
                flags_valid     <='1';
            
            --TAG                 
            
            when S_HDR_TAG        =>
                pdi_ready    <='1';
                len_SegLenCnt   <= pdi_valid and cmd_ready;
                
            
            when S_HDR_TAGLEN     =>
                pdi_ready       <='1';
                len_SegLenCnt   <= pdi_valid and cmd_ready;
            
            when S_HDR_RESTAG     => 
                pdi_ready       <='1';
               
            
            when S_HDR_TAGLEN_MSB =>
                pdi_ready       <= '1';
                en_LenReg       <= pdi_valid ;
               
            
            when S_HDR_TAGLEN_LSB => 
                pdi_ready       <= '1';
                len_SegLenCnt   <= pdi_valid;
               
            
            when S_LD_TAG         =>
                bdi_type        <= HDR_TAG;
                flags_valid     <='1';
                if(decrypt_internal='1')then
                    if(TAG_INTERNAL)then
                        bdi_valid   <= pdi_valid;
                        pdi_ready   <= bdi_ready ;
                        en_SegLenCnt<= pdi_valid and bdi_ready;
                    else
                        pdi_ready   <= cmd_ready;
                        en_SegLenCnt<= pdi_valid and cmd_ready;
                        cmd_valid   <= pdi_valid;
                    end if;
                end if;
            --                    
            when S_WAIT           =>
                    flags_valid     <='1';    
            when others           =>
            
        end case;
    end process;
    
end PreProcessor;
