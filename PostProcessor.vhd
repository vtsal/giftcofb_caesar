--------------------------------------------------------------------------------
--! @File        : PostProcessor.vhd
--! @Brief       : PostProcessor for CAESWAR LW API
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
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.math_real."ceil";
use IEEE.math_real."log2";
use work.GeneralComponents_pkg.all;
use work.Design_pkg.all;
use work.CAESAR_LWAPI_pkg.all;


entity PostProcessor is
    Generic (
            G_TAG_SIZE      : integer := 128
    );
    Port (
            clk             : in  STD_LOGIC;
            rst             : in  STD_LOGIC;
            --! Data SIPO=============================================
            bdo             : in  STD_LOGIC_VECTOR(PW    -1 downto 0);
            bdo_valid       : in  STD_LOGIC;
            bdo_ready       : out STD_LOGIC;
            --!Cipher Core=============================================
            end_of_block    : in  STD_LOGIC;
            bdo_type        : in  STD_LOGIC_VECTOR(4    -1 downto 0);
            bdo_valid_bytes : in  STD_LOGIC_VECTOR(PWdiv8-1 downto 0);
            ---Header/Tag FIF=========================================
            cmd             : in  STD_LOGIC_VECTOR(PW    -1 downto 0);
            cmd_valid       : in  STD_LOGIC;
            cmd_ready       : out STD_LOGIC;
            --!Output=================================================
            do_data         : out STD_LOGIC_VECTOR(PW    -1 downto 0);
            do_valid        : out STD_LOGIC;
            do_ready        : in  STD_LOGIC;
            msg_auth        : in  std_logic;
            msg_auth_ready  : out std_logic;
            msg_auth_valid  : in  std_logic
         );

end PostProcessor;

architecture PostProcessor of PostProcessor is
    signal output_header   : std_logic_vector(PW  -1 downto 0);
    signal do_data1        : std_logic_vector(PW  -1 downto 0);
    signal do_valid1       : std_logic;
    signal len_SegLenCnt   : std_logic;
    signal en_SegLenCnt    : std_logic;
    signal dout_SegLenCnt  : std_logic_vector(16  -1 downto 0);
    signal load_SegLenCnt  : std_logic_vector(16  -1 downto 0);
    signal HDR_TAG_internal: std_logic_vector(32  -1 downto 0);
    signal en_LenReg       : std_logic;
    signal last_segment    : std_logic;
    signal dout_mlen1      : std_logic_vector(PW  -1 downto 0);
    signal dout_LenReg     : std_logic_vector(8   -1 downto 0);
    signal tag_size        : std_logic_vector(16  -1 downto 0);
    signal tag_compare_fail: std_logic:='1';
    signal header_info     : std_logic;
    signal NumOfValidWords : integer;
    signal ena_ZeroData    : std_logic;
    signal len_ZeroData    : std_logic;
    signal dout_ZeroData   : std_logic;
    signal decrypt         : std_logic;
    signal ena_ModeReg     : std_logic;
    signal tag_blocks_count: integer:=0;
    constant zero_data     : std_logic_vector(PW    -1 downto 0):=(others=>'0');
    ---STATES
    type t_state is (S_INIT,
                     --MSG
                     S_HDR_MSG, S_HDR_MSGLEN, S_HDR_RESMSG,
                     S_HDR_MSGLEN_MSB, S_HDR_MSGLEN_LSB, S_OUT_MSG,
                     --TAG
                     S_HDR_TAG, S_HDR_TAGLEN, S_HDR_RESTAG,
                     S_HDR_TAGLEN_MSB, S_HDR_TAGLEN_LSB, S_OUT_TAG,
                     S_VER_TAG_IN, S_VER_TAG_EX,
                     S_STATUS_FAIL, S_STATUS_SUCCESS,
                     S_STATUS_MSB, S_STATUS_LSB, S_STATUS_ZERO
                     );
    signal nx_state, pr_state:t_state;
begin
    with  to_integer(unsigned(bdo_valid_bytes)) select
    NumOfValidWords <= 1 when 8,
                       2 when 12,
                       3 when 14,
                       1 when 1,
                       2 when 3,
                       4 when others;

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
    dout_mlen1   <= cmd;
    last_segment <= '1' when (to_integer(unsigned(dout_SegLenCnt))<=PWdiv8) else '0';
    tag_size     <= std_logic_vector(to_unsigned(G_TAG_SIZE/8, 16));

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

    ModeReg:    Reg
                port map(
                        clk               => clk,
                        ena               => ena_ModeReg,
                        din               => cmd(PW-4),
                        dout              => decrypt
                        );
    --decrypt<=decrypt_internal;

    HDR_TAG_internal <= HDR_TAG & x"300"& tag_size(15 downto 0);

    seg_16bit:
    if(PW=16) generate
    load_SegLenCnt <= dout_mlen1(PW-1 downto PW-8*PWdiv8);
    end generate;

    seg_32bit:
    if(PW=32) generate
    load_SegLenCnt <= dout_mlen1(PW-1-4*PWdiv8 downto 0);
    end generate;


    --!FSM FOR POSTPROCESSOR
    --=====STATE REGISTER=======================================================
    process (clk,rst)
    begin
        if(rst='1')  then
            pr_state <= S_INIT;
        elsif rising_edge(clk) then
            pr_state <= nx_state;
        end if;
    end process;
    --==========================================================================
    --!next state function
    --==========================================================================
    proc_32bit:
    if(pw=32) generate
    process (pr_state, bdo_valid, bdo, do_ready, end_of_block, decrypt,
             cmd_valid, cmd, msg_auth_valid, msg_auth, last_segment,
             tag_size,numofvalidwords,tag_compare_fail, HDR_TAG_internal,
             header_info,dout_zerodata,dout_LenReg)

    begin

        do_data1 <= (others => '-');
        ena_ZeroData <= '-';
        case pr_state is

            when S_INIT=>
                if(cmd_valid='1')then

                        nx_state <= S_HDR_MSG;
                        ena_ZeroData<='0';
                else
                    nx_state <= S_INIT;
                end if;

            when S_HDR_MSG=>
                if(cmd_valid='1' and do_ready='1') then
                    if(cmd(15 downto 0)=x"0000")then
                        if(decrypt='1')then
                            if(TAG_INTERNAL)then
                                nx_state <= S_VER_TAG_IN;
                            else
                                nx_state <= S_VER_TAG_EX;
                            end if;
                        else
                            nx_state <= S_HDR_TAG;
                        end if;
                    else
                        nx_state  <= S_OUT_MSG;
                    end if;
                else
                    nx_state <= S_HDR_MSG;
                end if;
                if(decrypt='1')then
                    --header is msg
                    do_data1(PW-1 downto PW-4)<= HDR_MSG;
                else
                    ---header is ciphertext
                    do_data1(PW-1 downto PW-4)<= HDR_CT;
                end if;
                do_data1(PW-5 downto PW-7)<= "001"; 
                do_data1(PW-8)<= not cmd(PW-7-1); 
                do_data1(PW-1-PWdiv8*2 downto 0)<= cmd(PW-1-PWdiv8*2 downto 0);

            when S_OUT_MSG =>
                if(bdo_valid='1' and do_ready='1' and end_of_block='1')then
                    if(last_segment='1') then
                        if(decrypt='1')then
                            if(TAG_INTERNAL)then
                                nx_state <= S_VER_TAG_IN;
                            else
                                nx_state <= S_VER_TAG_EX;
                            end if;
                        else
                            nx_state <= S_HDR_TAG;
                        end if;
                    else
                        nx_state <= S_OUT_MSG;
                    end if;
                else
                    nx_state <= S_OUT_MSG;
                end if;
                do_data1 <= bdo;
            --TAG

            when S_HDR_TAG=>
                if(do_ready='1' )then
                    nx_state  <= S_OUT_TAG;
                else
                    nx_state <= S_HDR_TAG;
                end if;

                do_data1(PW-1 downto 0)<= HDR_TAG_internal(31 downto 32-PW);

            when S_OUT_TAG =>
                if(bdo_valid='1' and end_of_block='1' and do_ready='1') then
                    nx_state <= S_STATUS_SUCCESS;
                else
                    nx_state <= S_OUT_TAG;
                end if;
                do_data1 <= bdo;

            when  S_VER_TAG_IN=>
                if(msg_auth_valid='1')then
                    if(msg_auth='1')then
                        nx_state <= S_STATUS_SUCCESS;
                    else
                        nx_state <= S_STATUS_FAIL;
                    end if;
                else
                    nx_state <= S_VER_TAG_IN;
                end if;

            when  S_VER_TAG_EX=>
                if(cmd_valid='1' and bdo_valid='1')then
                    if(tag_compare_fail='1')then
                        nx_state<= S_STATUS_FAIL;
                    elsif(end_of_block='1')then
                        nx_state <= S_STATUS_SUCCESS;
                    else
                        nx_state <= S_VER_TAG_EX;
                    end if;
                else
                    nx_state <= S_VER_TAG_EX;
                end if;

            when  S_STATUS_FAIL=>
                if(do_ready='1')then
                    nx_state<= S_INIT;
                else
                    nx_state<= S_STATUS_FAIL;
                end if;
                do_data1(PW-1 downto PW-4)<="1111";
                do_data1(PW-5 downto 0)   <= (others=>'0');

            when  S_STATUS_SUCCESS=>
                if(do_ready='1')then
                    nx_state<= S_INIT;
                else
                    nx_state<= S_STATUS_SUCCESS;
                end if;
                do_data1(PW-1 downto PW-4)<="1110";
                do_data1(PW-5 downto 0)   <= (others=>'0');
            when  others=>
                nx_state <= S_INIT;

        end case;
    end process;
end generate;
--==============================================================================
    proc_8bit:
    if(PW=8) generate
    process (pr_state, bdo_valid, bdo, do_ready, end_of_block, decrypt,
             cmd_valid, cmd, msg_auth_valid, msg_auth, last_segment,
             tag_size,numofvalidwords,tag_compare_fail, HDR_TAG_internal,
             header_info,dout_zerodata,dout_LenReg)

    begin
        do_data1 <= (others => '-');
        ena_ZeroData <= '-';
        case pr_state is

            when S_INIT=>
                if(cmd_valid='1')then
                        nx_state <= S_HDR_MSG;
                        ena_ZeroData<='0';
                else
                    nx_state <= S_INIT;
                end if;

            when S_HDR_MSG=>
                if(cmd_valid='1' and do_ready='1') then
                        nx_state  <= S_HDR_RESMSG;
                else
                    nx_state <= S_HDR_MSG;
                end if;

                if(decrypt='1')then
                    --header is msg
                    do_data1(PW-1 downto PW-4)<= HDR_MSG;
                  --  do_data1(PW-8)<= '1';
                else
                    ---header is ciphertext
                    do_data1(PW-1 downto PW-4)<= HDR_CT;
                 end if;
                do_data1(PW-5 downto PW-7)<= "001"; 
                do_data1(PW-8)<= not cmd(PW-7-1); 

            when S_HDR_RESMSG=>
                if(cmd_valid='1' and do_ready='1') then
                    nx_state <= S_HDR_MSGLEN_MSB;
                else
                    nx_state <= S_HDR_RESMSG;
                end if;
                do_data1<= cmd;

            when S_HDR_MSGLEN_MSB=>
                if(cmd_valid='1' and do_ready='1') then
                    nx_state <= S_HDR_MSGLEN_LSB;
                else
                    nx_state <= S_HDR_MSGLEN_MSB;
                end if;
                do_data1<= cmd;

            when S_HDR_MSGLEN_LSB=>
               
                if(dout_LenReg=x"00" and cmd(7 downto 0)=x"00" and do_ready='1' and cmd_valid='1')then
                    if(decrypt='1')then
                        if(TAG_INTERNAL)then
                            nx_state <= S_VER_TAG_IN;
                        else
                            nx_state <= S_VER_TAG_EX;
                            end if;
                        else
                            nx_state <= S_HDR_TAG;
                        end if;
                elsif(cmd_valid='1' and do_ready='1') then
                    nx_state <= S_OUT_MSG;
                else
                    nx_state <= S_HDR_MSGLEN_LSB;
                end if;
                do_data1<= cmd;

            when S_OUT_MSG =>
                if(bdo_valid='1' and do_ready='1' and end_of_block='1')then
                    if(last_segment='1') then
                        if(decrypt='1')then
                            if(TAG_INTERNAL)then
                                nx_state <= S_VER_TAG_IN;
                            else
                                nx_state <= S_VER_TAG_EX;
                            end if;
                        else
                            nx_state <= S_HDR_TAG;
                        end if;
                    else
                        nx_state <= S_OUT_MSG;
                    end if;
                else
                    nx_state <= S_OUT_MSG;
                end if;
                do_data1 <= bdo;

            --TAG
            when S_HDR_TAG=>
                if(do_ready='1' )then
                        nx_state <= S_HDR_RESTAG;
                else
                    nx_state <= S_HDR_TAG;
                end if;


                do_data1(PW-1 downto 0)<= HDR_TAG_internal(31 downto 32-PW);



            when S_HDR_RESTAG=>
                if(do_ready='1') then
                    nx_state <= S_HDR_TAGLEN_MSB;
                else
                    nx_state <= S_HDR_RESTAG;
                end if;
                do_data1<= (others=>'0');

            when S_HDR_TAGLEN_MSB=>
                if(do_ready='1') then
                    nx_state <= S_HDR_TAGLEN_LSB;
                else
                    nx_state <= S_HDR_TAGLEN_MSB;
                end if;
                do_data1(PW-1 downto PW-8)<=tag_size(15 downto 8);

            when S_HDR_TAGLEN_LSB=>
                if(do_ready='1') then
                    nx_state <= S_OUT_TAG;
                else
                    nx_state <= S_HDR_TAGLEN_LSB;
                end if;
                do_data1(PW-1 downto PW-8)<=tag_size(7 downto 0);

            when S_OUT_TAG =>
                if(bdo_valid='1' and end_of_block='1' and do_ready='1') then
                    nx_state <= S_STATUS_SUCCESS;
                else
                    nx_state <= S_OUT_TAG;
                end if;
                do_data1 <= bdo;

            when  S_VER_TAG_IN=>
                if(msg_auth_valid='1')then
                    if(msg_auth='1')then
                        nx_state <= S_STATUS_SUCCESS;
                    else
                        nx_state <= S_STATUS_FAIL;
                    end if;
                else
                    nx_state <= S_VER_TAG_IN;
                end if;

            when  S_VER_TAG_EX=>
                if(cmd_valid='1' and bdo_valid='1')then
                    if(tag_compare_fail='1')then
                        nx_state<= S_STATUS_FAIL;
                    elsif(end_of_block='1')then
                        nx_state <= S_STATUS_SUCCESS;
                    else
                        nx_state <= S_VER_TAG_EX;
                    end if;
                else
                    nx_state <= S_VER_TAG_EX;
                end if;

            when  S_STATUS_FAIL=>
                if(do_ready='1')then
                    nx_state<= S_STATUS_MSB;
                else
                    nx_state<= S_STATUS_FAIL;
                end if;
                do_data1(PW-1 downto PW-4) <="1111";
                do_data1(PW-5 downto 0)  <= (others=>'0');

            when  S_STATUS_SUCCESS=>
                if(do_ready='1')then
                        nx_state<= S_STATUS_MSB;
                else
                    nx_state<= S_STATUS_SUCCESS;
                end if;
                do_data1(PW-1 downto PW-4)<="1110";
                do_data1(PW-5 downto 0)  <= (others=>'0');

            when S_STATUS_MSB=>
                if(do_ready='1')then
                    nx_state<= S_STATUS_LSB;
                else
                    nx_state<= S_STATUS_MSB;
                end if;
                do_data1<= (others=>'0');

            when S_STATUS_LSB=>
                if(do_ready='1')then
                    nx_state<= S_STATUS_ZERO;
                else
                    nx_state<= S_STATUS_LSB;
                end if;
                do_data1<= (others=>'0');

            when S_STATUS_ZERO=>
                if(do_ready='1')then
                    nx_state<= S_INIT;
                else
                    nx_state<= S_STATUS_ZERO;
                end if;
                do_data1<= (others=>'0');

            when others=>
                nx_state <= S_INIT;
        end case;
    end process;
    end generate;

    --==============================================================================
    proc_16bit:
    if(PW=16) generate
    process (pr_state, bdo_valid, bdo, do_ready, end_of_block, decrypt,
             cmd_valid, cmd, msg_auth_valid, msg_auth, last_segment,
             tag_size,numofvalidwords,tag_compare_fail, HDR_TAG_internal,
             header_info,dout_zerodata,dout_LenReg)

    begin

        do_data1 <= (others => '-');
        ena_ZeroData <= '-';
        case pr_state is

            when S_INIT=>
                if(cmd_valid='1')then
                        nx_state <= S_HDR_MSG;
                        ena_ZeroData<='0';
                else
                    nx_state <= S_INIT;
                end if;

            when S_HDR_MSG=>
                if(cmd_valid='1' and do_ready='1') then
                    nx_state  <= S_HDR_MSGLEN;
                else
                    nx_state <= S_HDR_MSG;
                end if;
                if(decrypt='1')then
                    --header is msg
                    do_data1(PW-1 downto PW-4)<= HDR_MSG;
                else
                    ---header is ciphertext
                    do_data1(PW-1 downto PW-4)<= HDR_CT;
                   
                end if;
                do_data1(PW-5 downto PW-7)<= "001"; 
                do_data1(PW-8)<= not cmd(PW-7-1); 
                do_data1(PW-1-PWdiv8*4 downto 0)<= cmd(PW-1-PWdiv8*4 downto 0);

            when S_HDR_MSGLEN=>
                if(cmd=zero_data and cmd_valid='1' and do_ready='1')then
                    if(decrypt='1')then
                        if(TAG_INTERNAL)then
                            nx_state <= S_VER_TAG_IN;
                        else
                            nx_state <= S_VER_TAG_EX;
                            end if;
                        else
                            nx_state <= S_HDR_TAG;
                        end if;
                elsif(cmd_valid='1' and do_ready='1') then
                    nx_state <= S_OUT_MSG;
                else
                    nx_state <= S_HDR_MSGLEN;
                end if;
                do_data1<= cmd;

            when S_OUT_MSG =>
                if(bdo_valid='1' and do_ready='1' and end_of_block='1')then
                    if(last_segment='1') then
                        if(decrypt='1')then
                            if(TAG_INTERNAL)then
                                nx_state <= S_VER_TAG_IN;
                            else
                                nx_state <= S_VER_TAG_EX;
                            end if;
                        else
                            nx_state <= S_HDR_TAG;
                        end if;
                    else
                        nx_state <= S_OUT_MSG;
                    end if;
                else
                    nx_state <= S_OUT_MSG;
                end if;
                do_data1 <= bdo;

            --TAG
            when S_HDR_TAG=>
                if(do_ready='1' )then
                    nx_state  <= S_HDR_TAGLEN;
                 else
                    nx_state <= S_HDR_TAG;
                end if;
                do_data1(PW-1 downto 0)<= HDR_TAG_internal(31 downto 32-PW);


            when S_HDR_TAGLEN=>
                if(do_ready='1') then
                    nx_state <= S_OUT_TAG;
                else
                    nx_state <= S_HDR_TAGLEN;
                end if;
                do_data1(PW-1 downto PW-PWdiv8*8)<=tag_size(PW-1 downto PW-PWdiv8*8);

            when S_OUT_TAG =>
                if(bdo_valid='1' and end_of_block='1' and do_ready='1') then
                    nx_state <= S_STATUS_SUCCESS;
                else
                    nx_state <= S_OUT_TAG;
                end if;
                do_data1 <= bdo;

            when  S_VER_TAG_IN=>
                if(msg_auth_valid='1')then
                    if(msg_auth='1')then
                        nx_state <= S_STATUS_SUCCESS;
                    else
                        nx_state <= S_STATUS_FAIL;
                    end if;
                else
                    nx_state <= S_VER_TAG_IN;
                end if;

            when  S_VER_TAG_EX=>
                if(cmd_valid='1' and bdo_valid='1')then
                    if(tag_compare_fail='1')then
                        nx_state<= S_STATUS_FAIL;
                    elsif(end_of_block='1')then
                        nx_state <= S_STATUS_SUCCESS;
                    else
                        nx_state <= S_VER_TAG_EX;
                    end if;
                else
                    nx_state <= S_VER_TAG_EX;
                end if;

            when  S_STATUS_FAIL=>
                if(do_ready='1')then
                    nx_state<= S_STATUS_ZERO;
                else
                    nx_state<= S_STATUS_FAIL;
                end if;
                do_data1(PW-1 downto PW-4)<="1111";
                do_data1(PW-5 downto 0)   <= (others=>'0');

            when  S_STATUS_SUCCESS=>
                if(do_ready='1')then
                    nx_state<= S_STATUS_ZERO;
                else
                    nx_state<= S_STATUS_SUCCESS;
                end if;
                do_data1(PW-1 downto PW-4)<="1110";
                do_data1(PW-5 downto 0)   <= (others=>'0');

            when S_STATUS_ZERO=>
                if(do_ready='1')then
                    nx_state<= S_INIT;
                else
                    nx_state<= S_STATUS_ZERO;
                end if;
                do_data1<= (others=>'0');

            when others=>
                nx_state <= S_INIT;
        end case;

    end process;
    end generate;
    --==========================================================================
    --!output state function
    --==========================================================================
    outfunc_8bit:
    if(PW=8) generate
    process(pr_state,bdo_valid, end_of_block,msg_auth_valid,msg_auth,
            decrypt, cmd,cmd_valid,do_ready,dout_ZeroData)
    begin
            --DEFAULT SIGNALS
            --external interface
            do_valid1        <='0';
            --Ciphercore
            bdo_ready       <='0';
            msg_auth_ready  <='0';
            ---header/tag-FIFO
            cmd_ready       <='0';
            ---internal
            -----counters
            len_SegLenCnt   <='0';
            --ena_HDRFlagsReg <='0';
            en_LenReg       <='0';
            en_SegLenCnt    <='0';
            header_info     <='0';
            ena_ModeReg     <='0';


        case pr_state is

                when S_INIT=>
                    ena_ModeReg     <= cmd_valid;
                    cmd_ready       <= '1';

                --!MSG/CT
                when S_HDR_MSG=>
                    cmd_ready       <= do_ready;
                    do_valid1       <= cmd_valid;
                    len_SegLenCnt   <= do_ready and cmd_valid;
                    header_info     <='1';

                when S_HDR_RESMSG=>
                    cmd_ready       <= do_ready;
                    do_valid1       <=cmd_valid;
                    header_info     <='1';

                when S_HDR_MSGLEN_MSB=>
                    cmd_ready       <= do_ready;
                    en_LenReg       <= do_ready and cmd_valid;
                    do_valid1       <= cmd_valid;
                    header_info     <= '1';

                when S_HDR_MSGLEN_LSB=>
                    cmd_ready       <= do_ready;
                    len_SegLenCnt   <= do_ready and cmd_valid;
                    do_valid1       <= cmd_valid;
                    header_info     <= '1';

                when S_OUT_MSG=>
                    bdo_ready       <= do_ready;
                    do_valid1       <= bdo_valid;
                    en_SegLenCnt    <= bdo_valid and do_ready;

                --TAG

                when S_HDR_TAG=>
                    do_valid1        <='1';
                    header_info      <='1';

                when S_HDR_RESTAG=>
                    do_valid1        <='1';
                    header_info      <='1';

                when S_HDR_TAGLEN_MSB=>
                    do_valid1       <='1';
                    header_info     <='1';

                when S_HDR_TAGLEN_LSB=>
                    do_valid1       <='1';
                    header_info     <='1';

                when S_OUT_TAG=>
                    bdo_ready       <= do_ready;
                    do_valid1       <= bdo_valid;

                when S_VER_TAG_IN=>
                    msg_auth_ready  <= '1';

                when S_VER_TAG_EX =>
                    bdo_ready       <= cmd_valid;
                    cmd_ready       <= bdo_valid;

                when S_STATUS_FAIL=>
                     do_valid1      <= '1';

                when S_STATUS_SUCCESS=>
                     do_valid1      <= '1';

                when S_STATUS_MSB=>
                     do_valid1      <= '1';

                when S_STATUS_LSB=>
                     do_valid1      <= '1';

                when S_STATUS_ZERO=>
                     do_valid1      <= '1';


                when others=>

        end case;

    end process;
    end generate;
    --==============================================================================
    outfunc_16bit:
    if(PW=16) generate
    process(pr_state,bdo_valid, end_of_block,msg_auth_valid,msg_auth,
            decrypt, cmd,cmd_valid,do_ready,dout_ZeroData)
    begin
            --DEFAULT SIGNALS
            --external interface
            do_valid1        <='0';
            --Ciphercore
            bdo_ready       <='0';
            msg_auth_ready  <='0';
            ---header/tag-FIFO
            cmd_ready       <='0';
            ---internal
            -----counters
            len_SegLenCnt   <='0';
            --ena_HDRFlagsReg <='0';
            en_LenReg       <='0';
            en_SegLenCnt    <='0';
            header_info     <='0';
            ena_ModeReg     <='0';


        case pr_state is
                when S_INIT=>
                    ena_ModeReg     <= cmd_valid;
                    cmd_ready       <= '1';
                --MSG

                when S_HDR_MSG=>
                    cmd_ready       <= do_ready;
                    do_valid1       <= cmd_valid;
                    len_SegLenCnt   <= do_ready and cmd_valid;
                    header_info     <='1';

                when S_HDR_MSGLEN=>
                    cmd_ready       <= do_ready;
                    len_SegLenCnt   <= do_ready and cmd_valid;
                    do_valid1       <= cmd_valid;
                    header_info     <= '1';

                when S_OUT_MSG=>
                    bdo_ready       <= do_ready;
                    do_valid1       <= bdo_valid;
                    en_SegLenCnt    <= bdo_valid and do_ready;

                --TAG

                when S_HDR_TAG=>
                    do_valid1        <='1';
                    header_info     <='1';

                when S_HDR_TAGLEN=>
                    do_valid1        <='1';
                    header_info     <='1';

                when S_OUT_TAG=>
                     bdo_ready       <= do_ready;
                     do_valid1       <= bdo_valid;

                when S_VER_TAG_IN=>
                    msg_auth_ready   <= '1';

                when S_VER_TAG_EX =>

                        bdo_ready     <= cmd_valid;
                        cmd_ready     <= bdo_valid;

                when S_STATUS_FAIL=>
                     do_valid1       <= '1';

                when S_STATUS_SUCCESS=>
                     do_valid1       <= '1';

                when S_STATUS_ZERO=>
                     do_valid1       <= '1';


                when others=>

        end case;

    end process;
    end generate;
    --==============================================================================
    outfunc_32bit:
    if(PW=32) generate
    process(pr_state,bdo_valid, end_of_block,msg_auth_valid,msg_auth,
            decrypt, cmd,cmd_valid,do_ready,dout_ZeroData)
    begin
            --DEFAULT SIGNALS
            --external interface
            do_valid1        <='0';
            --Ciphercore
            bdo_ready       <='0';
            msg_auth_ready  <='0';
            ---header/tag-FIFO
            cmd_ready       <='0';
            ---internal
            -----counters
            len_SegLenCnt   <='0';
            --ena_HDRFlagsReg <='0';
            en_LenReg       <='0';
            en_SegLenCnt    <='0';
            header_info     <='0';
            ena_ModeReg     <='0';

        case pr_state is
                when S_INIT=>
                    ena_ModeReg<= cmd_valid;
                    cmd_ready  <= '1';
                --MSG

                when S_HDR_MSG=>
                    cmd_ready      <= do_ready;
                    do_valid1      <= cmd_valid;
                    len_SegLenCnt  <= do_ready and cmd_valid;
                    header_info     <='1';


                when S_OUT_MSG=>
                    bdo_ready        <= do_ready;
                    do_valid1        <= bdo_valid;
                    en_SegLenCnt     <= bdo_valid and do_ready;


                when S_HDR_TAG=>
                    do_valid1        <= '1';
                    header_info      <= '1';

                when S_OUT_TAG=>
                     bdo_ready       <= do_ready;
                     do_valid1       <= bdo_valid;

                when S_VER_TAG_IN=>
                    msg_auth_ready   <= '1';

                when S_VER_TAG_EX =>
                     bdo_ready     <= cmd_valid;
                     cmd_ready     <= bdo_valid;

                when S_STATUS_FAIL=>
                     do_valid1       <= '1';

                when S_STATUS_SUCCESS=>
                     do_valid1       <= '1';

                when S_STATUS_ZERO=>
                     do_valid1       <= '1';


                when others=>

        end case;

    end process;
    end generate;
    --==============================================================================
    do_valid<= do_valid1;
    do_data <= do_data1 when (do_valid1='1') else (others=>'Z');
    --=================================================
    ---TAG Comparator
        tag_compare_fail<= '0' when bdo =cmd else '1';
    --=================================================
    ZeroData:   RegLd
                port map (
                        clk               => clk,
                        ena               => ena_ZeroData,
                        len               => len_ZeroData,
                        load              => '0',
                        din               => '1',
                        dout              => dout_ZeroData
                        );

end PostProcessor;

