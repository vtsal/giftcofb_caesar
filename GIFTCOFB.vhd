----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/05/2019 09:26:06 PM
-- Design Name: 
-- Module Name: GIFTCOFB - Behavioral
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.SomeFunc.all;
use work.design_pkg.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

-- Entity
----------------------------------------------------------------------
entity GIFTCOFB is
    Port(
        clk             : in std_logic;
        rst             : in std_logic;
        -- Data Input
        key             : in std_logic_vector(31 downto 0); -- SW = 32
        bdi             : in std_logic_vector(31 downto 0); -- W = 32
        -- Key Control
        key_valid       : in std_logic;
        key_ready       : out std_logic;
        key_update      : in std_logic;
        -- BDI Control
        bdi_valid       : in std_logic;
        bdi_ready       : out std_logic;
        bdi_partial     : in std_logic;
        bdi_pad_loc     : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_valid_bytes : in std_logic_vector(3 downto 0); -- W/8 = 4
        bdi_size        : in std_logic_vector(2 downto 0); -- W/(8+1) = 3
        bdi_eot         : in std_logic;
        bdi_eoi         : in std_logic;
        bdi_type        : in std_logic_vector(3 downto 0);
        decrypt_in      : in std_logic;
        -- Data Output
        bdo             : out std_logic_vector(31 downto 0); -- W = 32
        -- BDO Control
        bdo_valid       : out std_logic;
        bdo_ready       : in std_logic;
        bdo_valid_bytes : out std_logic_vector(3 downto 0); -- W/8 = 4
        end_of_block    : out std_logic;
        bdo_type        : out std_logic_vector(3 downto 0);
        decrypt_out     : out std_logic;
        -- Tag Verification
        msg_auth        : out std_logic;
        msg_auth_valid  : out std_logic;
        msg_auth_ready  : in std_logic    
    );
end GIFTCOFB;

-- Architecture
----------------------------------------------------------------------
architecture Behavioral of GIFTCOFB is

    -- Constants -----------------------------------------------------
    --bdi_type and bdo_type encoding
    constant HDR_AD         : std_logic_vector(3 downto 0) := "0001";
    constant HDR_MSG        : std_logic_vector(3 downto 0) := "0100";
    constant HDR_CT         : std_logic_vector(3 downto 0) := "0101";
    constant HDR_TAG        : std_logic_vector(3 downto 0) := "1000";
    constant HDR_KEY        : std_logic_vector(3 downto 0) := "1100";
    constant HDR_NPUB       : std_logic_vector(3 downto 0) := "1101";
    
    constant zero64         : std_logic_vector(63 downto 0) := (others => '0');
    
    -- Types ---------------------------------------------------------
    type fsm is (idle, wait_key, load_key, wait_Npub, load_Npub, process_Npub, wait_AD,
                 load_AD, process_AD, wait_data, load_data, process_data, prepare_output_data,
                 output_data, process_tag, output_tag, wait_tag, load_tag,verify_tag, AD_delta1,
                 AD_delta2, AD_delta3, M_delta1, M_delta2, M_delta3);

    -- Signals -------------------------------------------------------
    -- GIFT signals
    signal X_in             : std_logic_vector(127 downto 0);
    signal Y_out            : std_logic_vector(127 downto 0);
    signal GIFT_start       : std_logic;
    signal GIFT_done        : std_logic;

    -- Data signals
    signal bdoReg_rst       : std_logic;
    signal bdoReg_en        : std_logic;
    signal bdoReg_in        : std_logic_vector(31 downto 0);
    
    signal KeyReg128_rst    : std_logic;
    signal KeyReg128_en     : std_logic;
    signal KeyReg128_in     : std_logic_vector(127 downto 0);
    signal secret_key_reg   : std_logic_vector(127 downto 0);
    
    signal iDataReg_rst     : std_logic;
    signal iDataReg_en      : std_logic;
    signal iDataReg_in      : std_logic_vector(127 downto 0);
    signal iDataReg_out     : std_logic_vector(127 downto 0);
    
    signal oDataReg_rst     : std_logic;
    signal oDataReg_en      : std_logic;
    signal oDataReg_in      : std_logic_vector(127 downto 0);
    signal oDataReg_out     : std_logic_vector(127 downto 0);
    
    signal MpadReg_rst      : std_logic;
    signal MpadReg_en       : std_logic;
    signal MpadReg_in       : std_logic_vector(127 downto 0);
    signal MpadReg_out      : std_logic_vector(127 downto 0);
    
    signal DeltaReg_rst     : std_logic;
    signal DeltaReg_en      : std_logic;
    signal DeltaReg_in      : std_logic_vector(63 downto 0);
    signal delta            : std_logic_vector(63 downto 0); -- Delta state
  
    -- Control Signals
    signal ValidBytesReg_rst: std_logic;
    signal ValidBytesReg_en : std_logic;
    signal ValidBytesReg_out: std_logic_vector(3 downto 0);
    
    signal bdiSizeReg_rst   : std_logic;
    signal bdiSizeReg_en    : std_logic;
    signal bdi_size_reg     : std_logic_vector(2 downto 0);
    
    signal bdi_eot_rst      : std_logic;
    signal bdi_eot_en       : std_logic;
    signal bdi_eot_reg      : std_logic;
    
    signal bdi_eoi_rst      : std_logic;
    signal bdi_eoi_en       : std_logic;
    signal bdi_eoi_reg      : std_logic;
    
    signal decrypt_rst      : std_logic;
    signal decrypt_set      : std_logic;
    signal decrypt_reg      : std_logic;
    
    signal last_AD_reg      : std_logic;
    signal last_AD_rst      : std_logic;
    signal last_AD_set      : std_logic;
    
    signal half_AD_reg      : std_logic;
    signal half_AD_rst      : std_logic;
    signal half_AD_set      : std_logic;
    
    signal no_AD_reg        : std_logic;
    signal no_AD_rst        : std_logic;
    signal no_AD_set        : std_logic;
    
    signal last_M_reg       : std_logic;
    signal last_M_rst       : std_logic;
    signal last_M_set       : std_logic;
    
    signal half_M_reg       : std_logic;
    signal half_M_rst       : std_logic;
    signal half_M_set       : std_logic;
    
    signal no_M_reg         : std_logic;
    signal no_M_rst         : std_logic;
    signal no_M_set         : std_logic;
    
    signal bdo_valid_rst    : std_logic;
    signal bdo_valid_set    : std_logic;
    
    signal end_of_block_rst : std_logic;
    signal end_of_block_set : std_logic;
    signal end_of_block_M   : std_logic;
    
    signal bdoTypeReg_rst   : std_logic;
    signal bdoTypeReg_en    : std_logic := '0';
    signal bdoTypeReg_in    : std_logic_vector(3 downto 0);

    -- Counter signals
    signal ctr_words_rst    : std_logic;
    signal ctr_words_inc    : std_logic;
    signal ctr_words        : std_logic_vector(2 downto 0);
    
    signal ctr_delta_rst    : std_logic;
    signal ctr_delta_inc    : std_logic;
    signal ctr_delta        : std_logic_vector(1 downto 0); -- Counter for delta states
    
    signal ctr_bytes_rst    : std_logic;
    signal ctr_bytes_inc    : std_logic;
    signal ctr_bytes_dec    : std_logic;
    signal ctr_bytes        : std_logic_vector(4 downto 0); -- Truncate the output based on this counter value
    -- State machine signals
    signal state            : fsm;
    signal next_state       : fsm;
    
    -- Components ----------------------------------------------------
    component GIFT128 is
        Port(
            clk, rst    : in std_logic;
            start       : in std_logic;
            Key         : in std_logic_vector(127 downto 0);
            X_in        : in std_logic_vector(127 downto 0);
            Y_out       : out std_logic_vector(127 downto 0);
            done        : out std_logic
        );
    end component GIFT128;
    
----------------------------------------------------------------------
begin
    
    Ek: GIFT128
    Port map(
        clk     => clk,
        rst     => rst,
        start   => GIFT_start,
        Key     => secret_key_reg,
        X_in    => X_in,
        Y_out   => Y_out,
        done    => GIFT_done
    );
    
    bdoReg: entity work.myReg
    generic map( b => 32)
    Port map(
        clk     => clk,
        rst     => bdoReg_rst,
        en      => bdoReg_en,
        D_in    => bdoReg_in,
        D_out   => bdo
    );
    
    KeyReg128: entity work.myReg
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => KeyReg128_rst,
        en      => KeyReg128_en,
        D_in    => KeyReg128_in,
        D_out   => secret_key_reg
    );
     
    iDataReg: entity work.myReg
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => iDataReg_rst,
        en      => iDataReg_en,
        D_in    => iDataReg_in,
        D_out   => iDataReg_out
    );
    
    oDataReg: entity work.myReg
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => oDataReg_rst,
        en      => oDataReg_en,
        D_in    => oDataReg_in,
        D_out   => oDataReg_out
    );
    
    MpadReg: entity work.myReg
    generic map( b => 128)
    Port map(
        clk     => clk,
        rst     => MpadReg_rst,
        en      => MpadReg_en,
        D_in    => MpadReg_in,
        D_out   => MpadReg_out
    );

    DeltaReg: entity work.myReg
    generic map( b => 64)
    Port map(
        clk     => clk,
        rst     => DeltaReg_rst,
        en      => DeltaReg_en,
        D_in    => DeltaReg_in,
        D_out   => delta
    );
    
    ValidBytesReg: entity work.myReg
    generic map( b => 4)
    Port map(
        clk     => clk,
        rst     => ValidBytesReg_rst,
        en      => ValidBytesReg_en,
        D_in    => bdi_valid_bytes,
        D_out   => ValidBytesReg_out
    );
    
    bdoTypeReg: entity work.myReg
    generic map( b => 4)
    Port map(
        clk     => clk,
        rst     => bdoTypeReg_rst,
        en      => bdoTypeReg_en,
        D_in    => bdoTypeReg_in,
        D_out   => bdo_type
    );
    
    
    Sync: process(clk)
    begin
        if rising_edge(clk) then
            if (rst = '1') then
                state   <= idle;
            else
                state   <= next_state;
            
                if (ctr_words_rst = '1') then
                    ctr_words   <= "000";
                elsif (ctr_words_inc = '1') then
                    ctr_words   <= ctr_words + 1;
                end if;
                
                if (ctr_delta_rst = '1') then
                    ctr_delta   <= "00";
                elsif (ctr_delta_inc = '1') then
                    ctr_delta   <= ctr_delta + 1;
                end if;
                
                if (ctr_bytes_rst = '1') then
                    ctr_bytes   <= "00000";
                elsif (ctr_bytes_inc = '1') then
                    ctr_bytes   <= ctr_bytes + bdi_size;
                elsif (ctr_bytes_dec = '1') then
                    ctr_bytes   <= ctr_bytes - 4;
                end if;
                
                if (decrypt_rst = '1') then
                    decrypt_reg <= '0';
                elsif (decrypt_set = '1') then
                    decrypt_reg <= '1';
                end if;
                
                if (last_AD_rst = '1') then
                    last_AD_reg <= '0';
                elsif (last_AD_set = '1') then
                    last_AD_reg <= '1';
                end if;
                
                if (half_AD_rst = '1') then
                    half_AD_reg <= '0';
                elsif (half_AD_set = '1') then
                    half_AD_reg <= '1';
                end if;
                
                if (no_AD_rst = '1') then
                    no_AD_reg   <= '0';
                elsif (no_AD_set = '1') then
                    no_AD_reg   <= '1';
                end if;
                
                if (last_M_rst = '1') then
                    last_M_reg  <= '0';
                elsif (last_M_set = '1') then
                    last_M_reg  <= '1';
                end if;
                
                if (half_M_rst = '1') then
                    half_M_reg  <= '0';
                elsif (half_M_set = '1') then
                    half_M_reg  <= '1';
                end if;
                
                if (no_M_rst = '1') then
                    no_M_reg   <= '0';
                elsif (no_M_set = '1') then
                    no_M_reg   <= '1';
                end if;
                
                if (bdo_valid_rst = '1') then
                    bdo_valid   <= '0';
                elsif (bdo_valid_set = '1') then
                    bdo_valid   <= '1';
                end if;
                 
                if (end_of_block_rst = '1') then
                    end_of_block   <= '0';
                elsif (end_of_block_set = '1') then
                    end_of_block   <= '1';
                elsif (end_of_block_M = '1') then
                    end_of_block   <= last_M_reg;
                end if;
                    
            end if;
        end if;
    end process;
    
    Controller: process(state, key, bdi, key_valid, key_update, bdi_valid, bdi_eot, bdi_eoi, bdi_type, ctr_words, ctr_delta, GIFT_done, bdo_ready, msg_auth_ready)
    begin
        next_state          <= idle;
        key_ready           <= '0';
        bdi_ready           <= '0';
        ctr_words_rst       <= '0';
        ctr_words_inc       <= '0';
        ctr_delta_rst       <= '0';
        ctr_delta_inc       <= '0'; 
        ctr_bytes_rst       <= '0';
        ctr_bytes_inc       <= '0';
        ctr_bytes_dec       <= '0';
        bdoReg_rst          <= '0';
        bdoReg_en           <= '0';
        bdoReg_in           <= (others => '0');
        KeyReg128_rst       <= '0';
        KeyReg128_en        <= '0';
        KeyReg128_in        <= (others => '0');
        iDataReg_rst        <= '0';
        iDataReg_en         <= '0';
        iDataReg_in         <= (others => '0');
        oDataReg_rst        <= '0';
        oDataReg_en         <= '0';
        oDataReg_in         <= (others => '0');
        MpadReg_rst         <= '0';
        MpadReg_en          <= '0';
        MpadReg_in          <= (others => '0');
        DeltaReg_rst        <= '0';
        DeltaReg_en         <= '0';
        DeltaReg_in         <= (others => '0');
        ValidBytesReg_rst   <= '0';
        ValidBytesReg_en    <= '0';
        bdoTypeReg_rst      <= '0';
        bdoTypeReg_en       <= '0';
        bdoTypeReg_in       <= (others => '0');
        decrypt_rst         <= '0';
        decrypt_set         <= '0';
        last_AD_rst         <= '0';
        last_AD_set         <= '0';
        half_AD_rst         <= '0';
        half_AD_set         <= '0';
        no_AD_rst           <= '0';
        no_AD_set           <= '0';
        last_M_rst          <= '0';
        last_M_set          <= '0';
        half_M_rst          <= '0';
        half_M_set          <= '0';
        no_M_rst            <= '0';
        no_M_set            <= '0';
        bdo_valid_rst       <= '1'; -- The bdo_valid should be always zero, unless the ciphercore wants to put data on bdo
        bdo_valid_set       <= '0';
        bdo_valid_bytes     <= (others => '0');
        end_of_block_rst    <= '0';
        end_of_block_set    <= '0';
        end_of_block_M      <= '0'; -- It is used for output data, based on the input data
        decrypt_out         <= '0';
        msg_auth            <= '0';
        msg_auth_valid      <= '0';      
        GIFT_start          <= '0';
        X_in                <= (others => '0');
        
        
        case state is
            when idle =>
                ctr_words_rst   <= '1';
                ctr_delta_rst   <= '1';
                ctr_bytes_rst   <= '1';
                bdoReg_rst      <= '1';
                iDataReg_rst    <= '1';
                oDataReg_rst    <= '1';
                MpadReg_rst     <= '1';
                DeltaReg_rst    <= '1'; 
                decrypt_rst     <= '1';
                last_AD_rst     <= '1';
                half_AD_rst     <= '1';
                no_AD_rst       <= '1';
                last_M_rst      <= '1';
                half_M_rst      <= '1';
                no_M_rst        <= '1';
                end_of_block_rst<= '1';
                next_state      <= wait_key;
                
            when wait_key =>
                if (key_valid = '1' and key_update = '1') then
                    KeyReg128_rst   <= '1'; -- No need to keep the previous key
                    next_state      <= load_key;
                elsif (bdi_valid = '1') then
                    next_state      <= wait_Npub;
                else
                    next_state      <= wait_key;
                end if;
                
            when load_key =>
                key_ready           <= '1';
                KeyReg128_en        <= '1';
                KeyReg128_in        <= secret_key_reg(95 downto 0) & key;
                ctr_words_inc       <= '1';
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= wait_Npub;
                else
                    next_state      <= load_key;
                end if;
                
            when wait_Npub =>
                if (bdi_valid = '1' and bdi_type = HDR_NPUB) then
                    next_state  <= load_Npub;
                else
                    next_state  <= wait_Npub;
                end if;
                
            when load_Npub =>              
                bdi_ready           <= '1'; 
                iDataReg_en         <= '1';
                iDataReg_in         <= iDataReg_out(95 downto 0) & bdi;
                ctr_words_inc       <= '1';
                if (decrypt_in = '1') then -- Decryption
                    decrypt_set     <= '1';
                else                       -- Encryption
                    decrypt_rst     <= '1';
                end if;
                if (bdi_eoi = '1') then -- No AD and no data
                    no_AD_set       <= '1';
                    no_M_set        <= '1';
                end if;
                if (ctr_words = 3) then 
                    ctr_words_rst   <= '1';
                    next_state      <= process_Npub;
                else
                    next_state      <= load_Npub;
                end if;
                
            when process_Npub =>
                X_in                <= iDataReg_out; -- Here, iDataReg_out is the block of nonce
                GIFT_start          <= '1';
                if (GIFT_done = '1' and no_AD_reg = '1' and no_M_reg = '1') then -- No AD and no M, process the last Ek for preparing tag
                    GIFT_start      <= '0';
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Y_out(127 downto 64);
                    iDataReg_en     <= '1';
                    iDataReg_in(127)<= '1'; -- No AD, so put a padded data (0x80...00) as the first block of AD
                    next_state      <= AD_delta1; 
                elsif (GIFT_done = '1') then
                    GIFT_start      <= '0';
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Y_out(127 downto 64);
                    next_state      <= wait_AD;
                else
                    next_state      <= process_Npub;
                end if;
            
            when wait_AD =>
                if (bdi_valid = '1') then                   
                    if (bdi_type = HDR_AD) then
                        iDataReg_rst    <= '1';
                        next_state  <= load_AD;
                    elsif (bdi_type = HDR_MSG) then -- No AD, but we need to process a padded block of AD, before loading M blocks
                        no_AD_set                  <= '1';
                        iDataReg_en                <= '1';
                        iDataReg_in(127)           <= '1'; -- No AD, so put a padded data (0x80...00) as the first block of AD
                        next_state                 <= AD_delta1; 
                    end if;
                else
                    next_state  <= wait_AD;
                end if;    
            
            when load_AD =>
                bdi_ready       <= '1';
                iDataReg_en     <= '1';
                iDataReg_in     <= myMux(iDataReg_out(95 downto 0) & padding(bdi, conv_integer(bdi_size)), ctr_words, bdi_eot);
                ctr_words_inc   <= '1';
                if (bdi_eot = '1' and bdi_eoi = '1') then -- No data
                    no_M_set        <= '1';
                end if;
                if (bdi_eot = '1') then -- Last block of AD
                    last_AD_set     <= '1';
                end if;
                if (bdi_eot = '1' and bdi_size /= 4) then -- Partial block of AD
                    half_AD_set     <= '1';
                end if; 
                if (bdi_eot = '1' or ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= AD_delta1;
                else
                    next_state      <= load_AD;
                end if;                   
                
            when AD_delta1 =>
                if (last_AD_reg = '1' or no_AD_reg = '1') then -- Last block of AD or no AD
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Tripling(delta);
                else 
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Doubling(delta);
                end if;
                next_state          <= AD_delta2;
                
            when AD_delta2 =>
                if (half_AD_reg = '1' or no_AD_reg = '1') then -- Partial or empty block of AD
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Tripling(delta);
                end if;
                next_state          <= AD_delta3;
            
            when AD_delta3 =>
                ctr_delta_inc       <= '1';
                if (no_M_reg = '1' and ctr_delta < 2) then -- No data, so delta state needs two triples
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Tripling(delta);
                end if;
                if (ctr_delta = 1) then
                    ctr_delta_rst   <= '1';
                    next_state      <= process_AD;
                else 
                    next_state      <= AD_delta3;
                end if;
            
            when process_AD =>
                X_in            <= rho1(Y_out, iDataReg_out) xor (delta & zero64); -- Here, iDataReg_out is a block of AD
                GIFT_start      <= '1';
                if (GIFT_done = '1' and no_M_reg = '1' and (last_AD_reg = '1' or no_AD_reg = '1')) then -- No data, go to process tag
                    GIFT_start  <= '0';
                    iDataReg_rst<= '1';
                    next_state  <= process_tag;
                elsif (GIFT_done = '1' and last_AD_reg = '0' and no_AD_reg = '0') then -- Still loading AD, if we have any AD
                    GIFT_start  <= '0';
                    next_state  <= wait_AD;
                elsif (GIFT_done = '1' and no_M_reg = '0') then -- No AD, start loading data
                    GIFT_start  <= '0';
                    next_state  <= wait_data;
                else
                    next_state  <= process_AD;
                end if;
            
            when wait_data =>
                if (bdi_valid = '1' and bdi_type = HDR_MSG) then
                    iDataReg_rst    <= '1';                
                    next_state      <= load_data;
                else
                    next_state      <= wait_data;
                end if;
                
            when load_data =>
                bdi_ready           <= '1';
                iDataReg_en         <= '1';
                ctr_words_inc       <= '1';
                ctr_bytes_inc       <= '1';
                iDataReg_in         <= myMux(iDataReg_out(95 downto 0) & padding(bdi, conv_integer(bdi_size)), ctr_words, bdi_eot);            
                if (bdi_eot = '1') then -- Last block of data
                    last_M_set      <= '1';
                end if;
                if (bdi_eot = '1' and bdi_size /= 4) then -- Partial block of data
                    half_M_set     <= '1';
                end if; 
                if (bdi_eot = '1' or ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= prepare_output_data;
                else
                    next_state      <= load_data;
                end if;    
            
            when prepare_output_data =>
                MpadReg_rst <= '1'; -- We need it for decryption
                oDataReg_en <= '1';
                oDataReg_in <= Y_out xor iDataReg_out; -- CT(PT) =  Y xor PT(CT)
                next_state  <= output_data;
            
            when output_data =>
                if (bdo_ready = '1') then
                    bdo_valid_rst   <= '0';
                    bdo_valid_set   <= '1'; -- Set bdo_valid
                    ctr_words_inc   <= '1';
                    decrypt_out     <= decrypt_reg;
                    bdoTypeReg_en   <= '1';
                    bdoTypeReg_in   <= HDR_CT;
                    if (ctr_bytes <= 4) then -- Last 4 bytes of data
                        end_of_block_M   <= '1';
                    else
                        end_of_block_rst <= '1';
                    end if;
                end if;
                if (bdo_ready = '1' and last_M_reg = '1' and ctr_bytes < 4) then -- Partial 32-bit of the last block of 128-bit output
                    ctr_words_rst   <= '1';
                    ctr_bytes_rst   <= '1';
                    bdo_valid_bytes <= ValidBytesReg_out;
                    bdoReg_en       <= '1';
                    bdoReg_in       <= Trunc(oDataReg_out((127 - conv_integer(ctr_words)*32) downto (96 - conv_integer(ctr_words)*32)), ctr_bytes);
                    MpadReg_en      <= '1';
                    MpadReg_in      <= myMux(MpadReg_out(127 downto 32) & padding(oDataReg_out((127 - conv_integer(ctr_words)*32) downto (96 - conv_integer(ctr_words)*32)), conv_integer(ctr_bytes)), ctr_words, '1'); 
                    next_state      <= M_delta1;
                elsif (bdo_ready = '1') then
                    bdo_valid_bytes <= "1111";
                    bdoReg_en       <= '1';
                    bdoReg_in       <= oDataReg_out((127 - conv_integer(ctr_words)*32) downto (96 - conv_integer(ctr_words)*32));
                    MpadReg_en      <= '1';
                    MpadReg_in      <= oDataReg_out;
                    ctr_bytes_dec   <= '1';
                    if (ctr_words = 3) then
                        ctr_words_rst   <= '1';
                        ctr_bytes_rst   <= '1';
                        next_state      <= M_delta1;
                    else
                        next_state  <= output_data;
                    end if;
                else
                    next_state      <= output_data;
                end if;
                
            when M_delta1 =>
                DeltaReg_en         <= '1';
                if (last_M_reg = '1') then -- Last block of data
                    DeltaReg_in     <= Tripling(delta);
                else 
                    DeltaReg_in     <= Doubling(delta);
                end if;
                next_state          <= M_delta2;
                
            when M_delta2 =>
                if (half_M_reg = '1') then -- Partial block of data
                    DeltaReg_en     <= '1';
                    DeltaReg_in     <= Tripling(delta);
                end if;
                next_state          <= process_data;
            
            when process_data =>
                if (decrypt_reg = '0') then -- Encryption
                    X_in        <= rho1(Y_out, iDataReg_out) xor (delta & zero64); -- Here, iDataReg_out is whether a block of PT or a block of CT
                else -- Decryption
                    X_in        <= rho1(Y_out, MpadReg_out) xor (delta & zero64);
                end if;
                GIFT_start      <= '1'; 
                if (GIFT_done = '1' and last_M_reg = '1') then -- End of data
                    GIFT_start  <= '0';
                    oDataReg_rst<= '1';
                    next_state  <= process_tag;
                elsif (GIFT_done = '1') then 
                    GIFT_start  <= '0';
                    next_state  <= wait_data;
                else
                    next_state  <= process_data;
                end if;
            
            when process_tag =>
                oDataReg_en     <= '1';
                oDataReg_in     <= Y_out;
                if (decrypt_reg = '0') then -- Encryption
                    next_state  <= output_tag;
                else -- Decryption
                    next_state  <= wait_tag;   
                end if;
                
            when output_tag =>
                if (bdo_ready = '1') then
                    bdo_valid_rst        <= '0';
                    bdo_valid_set        <= '1'; -- Set bdo_valid
                    bdo_valid_bytes      <= "1111";
                    bdoTypeReg_en        <= '1';
                    bdoTypeReg_in        <= HDR_TAG;
                    decrypt_out          <= decrypt_reg;
                    bdoReg_en            <= '1';
                    bdoReg_in            <= oDataReg_out((127 - conv_integer(ctr_words)*32) downto (96 - conv_integer(ctr_words)*32)); -- Here, iDataReg_out is the output tag
                    ctr_words_inc        <= '1';
                    if (ctr_words = 3) then -- Last 4 bytes of Tag
                        end_of_block_set <= '1';
                    else
                        end_of_block_rst <= '1';
                    end if;
                end if;
                if (ctr_words = 3) then
                    ctr_words_rst        <= '1';
                    next_state           <= idle;
                else
                    next_state           <= output_tag;
                end if; 

            when wait_tag =>
                if (bdi_valid = '1' and bdi_type = HDR_TAG) then
                    iDataReg_rst    <= '1'; 
                    next_state      <= load_tag;
                else
                    next_state      <= wait_tag;
                end if;
             
            when load_tag =>
                bdi_ready           <= '1';
                iDataReg_en         <= '1';
                iDataReg_in         <= iDataReg_out(95 downto 0) & bdi; -- Here, iDataReg_out is the input tag
                ctr_words_inc       <= '1';
                if (ctr_words = 3) then
                    ctr_words_rst   <= '1';
                    next_state      <= verify_tag;
                else
                    next_state      <= load_tag;
                end if;   
            
            when verify_tag =>
                if (msg_auth_ready = '1' and oDataReg_out = iDataReg_out) then -- Here, oDataReg_out is the output tag and iDataReg_out is the input tag
                    msg_auth_valid  <= '1';
                    msg_auth        <= '1';
                    next_state      <= idle; 
                elsif (msg_auth_ready = '1') then
                    msg_auth_valid  <= '1';
                    msg_auth        <= '0';
                    next_state      <= idle;
                else
                    next_state      <= verify_tag;
                end if;
 
            when others =>
                next_state  <= idle;
            
        end case;
    end process;

end Behavioral;
