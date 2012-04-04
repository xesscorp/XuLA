----------------------------------------------------------------------------------
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
-- 02111-1307, USA.
--
-- ©1997-2010 - X Engineering Software Systems Corp. (www.xess.com)
----------------------------------------------------------------------------------


----------------------------------------------------------------------------------
-- Module for testing board functionality.
----------------------------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;

package TestBoardCorePckg is

  component TestBoardCore is
    generic(
      FREQ_G        : real    := 100.0;  -- frequency of operation in MHz
      PIPE_EN_G     : boolean := true;  -- enable fast, pipelined SDRAM operation
      DATA_WIDTH_G  : natural := 16;    -- SDRAM data width
      SADDR_WIDTH_G : natural := 13;    -- SDRAM row/col address width
      NROWS_G       : natural := 4096;  -- number of rows in the SDRAM
      NCOLS_G       : natural := 512;   -- number of columns in each SDRAM row
      -- beginning and ending addresses for the entire SDRAM
      BEG_ADDR_G    : natural := 16#00_0000#;
      END_ADDR_G    : natural := 16#7F_FFFF#;
      -- beginning and ending address for the memory tester
      BEG_TEST_G    : natural := 16#00_0000#;
      END_TEST_G    : natural := 16#7F_FFFF#
      );
    port(
      clk_i       : in    std_logic;  -- main clock input from external clock source
      sdRas_bo    : out   std_logic;    -- SDRAM RAS
      sdCas_bo    : out   std_logic;    -- SDRAM CAS
      sdWe_bo     : out   std_logic;    -- SDRAM write-enable
      sdBs_o      : out   std_logic_vector(0 downto 0);  -- SDRAM bank-address
      sdAddr_o    : out   std_logic_vector(SADDR_WIDTH_G-1 downto 0);  -- SDRAM address bus
      sdData_io   : inout std_logic_vector(DATA_WIDTH_G-1 downto 0);  -- data from SDRAM
      progress_o  : out   std_logic_vector(1 downto 0);  -- test progress_o indicator
      err_o       : out   std_logic;  -- true if an error was found during test
      led_o       : out   std_logic_vector(15 downto 0);  -- dual seven-segment LEDs
      heartBeat_o : out   std_logic  -- heartBeat_o status (usually sent to parallel port status pin)
      );
  end component;

end package;




library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use WORK.CommonPckg.all;
use WORK.MemTestPckg.all;
use WORK.SdramCntlPckg.all;

entity TestBoardCore is
  generic(
    FREQ_G        : real    := 100.0;   -- frequency of operation in MHz
    PIPE_EN_G     : boolean := true;  -- enable fast, pipelined SDRAM operation
    DATA_WIDTH_G  : natural := 16;      -- SDRAM data width
    SADDR_WIDTH_G : natural := 13;      -- SDRAM row/col address width
    NROWS_G       : natural := 4096;    -- number of rows in the SDRAM
    NCOLS_G       : natural := 512;     -- number of columns in each SDRAM row
    -- beginning and ending addresses for the entire SDRAM
    BEG_ADDR_G    : natural := 16#00_0000#;
    END_ADDR_G    : natural := 16#7F_FFFF#;
    -- beginning and ending address for the memory tester
    BEG_TEST_G    : natural := 16#00_0000#;
    END_TEST_G    : natural := 16#7F_FFFF#
    );
  port(
    clk_i       : in    std_logic;  -- main clock input from external clock source
    sdRas_bo    : out   std_logic;      -- SDRAM RAS
    sdCas_bo    : out   std_logic;      -- SDRAM CAS
    sdWe_bo     : out   std_logic;      -- SDRAM write-enable
    sdBs_o      : out   std_logic_vector(0 downto 0);  -- SDRAM bank-address
    sdAddr_o    : out   std_logic_vector(SADDR_WIDTH_G-1 downto 0);  -- SDRAM address bus
    sdData_io   : inout std_logic_vector(DATA_WIDTH_G-1 downto 0);  -- data from SDRAM
    progress_o  : out   std_logic_vector(1 downto 0);  -- test progress_o indicator
    err_o       : out   std_logic;  -- true if an error was found during test
    led_o       : out   std_logic_vector(15 downto 0);  -- dual seven-segment LEDs
    heartBeat_o : out   std_logic  -- heartBeat_o status (usually sent to parallel port status pin)
    );
end entity;

architecture arch of TestBoardCore is
  constant HADDR_WIDTH_G : natural := Log2(END_ADDR_G-BEG_ADDR_G+1);
  signal rst_i           : std_logic;              -- internal reset signal
  signal divCnt          : unsigned(20 downto 0);  -- clock divider

  -- signals that go through the SDRAM host-side interface
  signal begun      : std_logic;        -- SDRAM operation started indicator
  signal earlyBegun : std_logic;        -- SDRAM operation started indicator
  signal done       : std_logic;        -- SDRAM operation complete indicator
  signal rdDone     : std_logic;        -- SDRAM operation complete indicator
  signal hAddr      : std_logic_vector(HADDR_WIDTH_G-1 downto 0);  -- host address bus
  signal hDIn       : std_logic_vector(DATA_WIDTH_G-1 downto 0);  -- host-side data to SDRAM
  signal hDOut      : std_logic_vector(DATA_WIDTH_G-1 downto 0);  -- host-side data from SDRAM
  signal rd         : std_logic;        -- host-side read control signal
  signal wr         : std_logic;        -- host-side write control signal
  signal rdPending  : std_logic;  -- read operation pending in SDRAM pipeline

  -- status signals from the memory tester
  signal progress_i : std_logic_vector(1 downto 0);  -- internal test progress_o indicator
  signal err_i      : std_logic;        -- test error flag

begin

  ------------------------------------------------------------------------
  -- internal reset flag is set active right after configuration is done
  -- because the reset counter starts at zero, and then gets reset after
  -- the counter reaches its upper threshold.
  ------------------------------------------------------------------------
  process(clk_i)
    constant reset_dly_c : natural                        := 100;
    variable rst_cntr    : natural range 0 to reset_dly_c := 0;
  begin
    if rising_edge(clk_i) then
      rst_i <= NO;
      if rst_cntr < reset_dly_c then
        rst_i    <= YES;
        rst_cntr := rst_cntr + 1;
      end if;
    end if;
  end process;

  ------------------------------------------------------------------------
  -- Instantiate a memory tester that supports memory pipelining if that option is enabled
  ------------------------------------------------------------------------
  gen_fast_memtest : if PIPE_EN_G generate
    fast_memtest : MemTest
      generic map(
        PIPE_EN_G    => PIPE_EN_G,
        DATA_WIDTH_G => DATA_WIDTH_G,
        ADDR_WIDTH_G => HADDR_WIDTH_G,
        BEG_TEST_G   => BEG_TEST_G,
        END_TEST_G   => END_TEST_G
        )
      port map(
        clk_i       => clk_i,           -- master internal clock
        rst_i       => rst_i,           -- reset
        doAgain_i   => NO,              -- run the test once
        begun_i     => earlyBegun,      -- SDRAM controller operation started
        done_i      => rdDone,          -- SDRAM controller operation complete
        dIn_i       => hDOut,  -- host-side data from SDRAM goes to memory tester
        rdPending_i => rdPending,  -- tell the memory tester if the SDRAM has pending reads
        rd_o        => rd,  -- host-side SDRAM read control from memory tester
        wr_o        => wr,  -- host-side SDRAM write control from memory tester
        addr_o      => hAddr,           -- host-side address from memory tester
        dOut_o      => hDIn,  -- host-side data to SDRAM comes from memory tester
        progress_o  => progress_i,      -- current phase of memory test
        err_o       => err_i            -- memory test error flag
        );
  end generate;

  ------------------------------------------------------------------------
  -- Instantiate memory tester without memory pipelining if that option is disabled
  ------------------------------------------------------------------------
  gen_slow_memtest : if not PIPE_EN_G generate
    slow_memtest : MemTest
      generic map(
        PIPE_EN_G    => PIPE_EN_G,
        DATA_WIDTH_G => DATA_WIDTH_G,
        ADDR_WIDTH_G => HADDR_WIDTH_G,
        BEG_TEST_G   => BEG_TEST_G,
        END_TEST_G   => END_TEST_G
        )
      port map(
        clk_i       => clk_i,           -- master internal clock
        rst_i       => rst_i,           -- reset
        doAgain_i   => NO,              -- run the test once
        begun_i     => begun,           -- SDRAM controller operation started
        done_i      => done,            -- SDRAM controller operation complete
        dIn_i       => hDOut,  -- host-side data from SDRAM goes to memory tester
        rdPending_i => rdPending,  -- tell the memory tester if the SDRAM has pending reads
        rd_o        => rd,  -- host-side SDRAM read control from memory tester
        wr_o        => wr,  -- host-side SDRAM write control from memory tester
        addr_o      => hAddr,           -- host-side address from memory tester
        dOut_o      => hDIn,  -- host-side data to SDRAM comes from memory tester
        progress_o  => progress_i,      -- current phase of memory test
        err_o       => err_i            -- memory test error flag
        );
  end generate;

  ------------------------------------------------------------------------
  -- Instantiate the SDRAM controller that connects to the memory tester
  -- module and interfaces to the external SDRAM chip.
  ------------------------------------------------------------------------
  u1 : SdramCntl
    generic map(
      FREQ_G        => FREQ_G,
      IN_PHASE_G    => true,
      PIPE_EN_G     => PIPE_EN_G,
      MAX_NOP_G     => 10000,
      DATA_WIDTH_G  => DATA_WIDTH_G,
      NROWS_G       => NROWS_G,
      NCOLS_G       => NCOLS_G,
      HADDR_WIDTH_G => HADDR_WIDTH_G,
      SADDR_WIDTH_G => SADDR_WIDTH_G
      )
    port map(
      clk_i          => clk_i,  -- master clock from external clock source (unbuffered)
      lock_i         => YES,   -- no DLLs, so frequency is always locked
      rst_i          => rst_i,          -- reset
      rd_i           => rd,  -- host-side SDRAM read control from memory tester
      wr_i           => wr,  -- host-side SDRAM write control from memory tester
      earlyOpBegun_o => earlyBegun,  -- early indicator that memory operation has begun
      opBegun_o      => begun,  -- indicates memory read/write has begun
      rdPending_o    => rdPending,  -- read operation to SDRAM is in progress_o
      done_o         => done,  -- SDRAM memory read/write done indicator
      rdDone_o       => rdDone,  -- indicates SDRAM memory read operation is done
      hostAddr_i     => hAddr,  -- host-side address from memory tester to SDRAM
      hostData_i     => hDIn,  -- test data pattern from memory tester to SDRAM
      sdramData_o    => hDOut,          -- SDRAM data output to memory tester
      status_o       => open,  -- SDRAM controller state (for diagnostics)
      sdRas_bo       => sdRas_bo,       -- SDRAM RAS
      sdCas_bo       => sdCas_bo,       -- SDRAM CAS
      sdWe_bo        => sdWe_bo,        -- SDRAM write-enable
      sdBs_o         => sdBs_o,         -- SDRAM bank address
      sdAddr_o       => sdAddr_o,       -- SDRAM address
      sdData_io      => sdData_io       -- data to/from SDRAM
      );

  ------------------------------------------------------------------------
  -- Indicate the phase of the memory tester on the segments of the 
  -- seven-segment led_o.  The phases of the memory test are
  -- indicated as shown below (|=led_o OFF; *=led_o ON):
  -- 
  --       ----*           *****            *****           ******           ******
  --      |    *          |    *           |    *           *    *           *    |
  --       ----*          ******            *****           *----*           ******
  --      |    *          *    |           |    *           *    *           *    |
  --       ----*          *****             *****           ******           ******
  --  Initialization  Writing pattern  Reading pattern    Memory test  or  Memory test
  --      Phase          to memory       from memory        passed           failed
  ------------------------------------------------------------------------
  led_o <= "0000000000000110" when progress_i = "00" else  -- "1" during initialization
           "0000000001011011" when progress_i = "01" else  -- "2" when writing to memory
           "0000000001001111" when progress_i = "10" else  -- "3" when reading from memory
           "0000000001111001" when err_i = YES       else  -- "E" if memory test failed
           "0000000000111111";          -- "O" if memory test passed

  ------------------------------------------------------------------------
  -- Generate some slow signals from the master clock.
  ------------------------------------------------------------------------
  process(clk_i)
  begin
    if rising_edge(clk_i) then
      divCnt <= divCnt+1;
    end if;
  end process;

  ------------------------------------------------------------------------
  -- Send a heartBeat_o signal back to the PC to indicate
  -- the status of the memory test:
  --   50% duty cycle -> test in progress_o
  --   75% duty cycle -> test passed
  --   25% duty cycle -> test failed
  ------------------------------------------------------------------------
  heartBeat_o <= divCnt(16) when progress_i /= "11" else  -- test in progress_o
                 divCnt(16) or divCnt(15) when err_i = NO else  -- test passed
                 divCnt(16) and divCnt(15);  -- test failed                              

  progress_o <= progress_i;
  err_o      <= err_i;

end architecture;
