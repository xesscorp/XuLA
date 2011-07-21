--------------------------------------------------------------------
-- Company       : XESS Corp.
-- Engineer      : Dave Vanden Bout
-- Creation Date : 05/17/2005
-- Copyright     : 2005, XESS Corp
-- Tool Versions : WebPACK 6.3.03i
--
-- Description:
--    Miscellaneous VHDL constants and functions.
--
-- Revision:
--    1.3.0
--
-- Additional Comments:
--    1.3.0:
--        Added IntMax() function.
--    1.2.0:
--        Added BinaryToGray() and GrayToBinary() functions.
--    1.1.0:
--        Added IntSelect() and RealSelect() functions.
--    1.0.0:
--        Initial release.
--
-- License:
--    This code can be freely distributed and modified as long as
--    this header is not removed.
--------------------------------------------------------------------



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package common is

  constant YES       :    std_logic := '1';
  constant NO        :    std_logic := '0';
  constant HI        :    std_logic := '1';
  constant LO        :    std_logic := '0';
  constant ONE       :    std_logic := '1';
  constant ZERO      :    std_logic := '0';
  constant HIZ       :    std_logic := 'Z';
  
  -- Types of FPGA chips.
  constant SPARTAN2_G  : natural := 1;
  constant SPARTAN2E_G : natural := 2;
  constant SPARTAN3_G  : natural := 3;

  -- Convert a Boolean to a std_logic.
  function BooleanToStdLogic(b : in boolean) return std_logic;
  -- Find the base-2 logarithm of a number.
  function Log2(v : in natural) return natural;
  -- Select one of two integers based on a Boolean.
  function IntSelect(s : in boolean; a : in integer; b : in integer) return integer;
  -- Select one of two reals based on a Boolean.
  function RealSelect(s : in boolean; a : in real; b : in real) return real;
  -- Convert a binary number to a graycode number.
  function BinaryToGray(b: in std_logic_vector) return std_logic_vector;
  -- Convert a graycode number to a binary number.
  function GrayToBinary(g: in std_logic_vector) return std_logic_vector;
  -- Find the maximum of two integers.
  function IntMax(a: in integer; b: in integer) return integer;

end package common;



library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;


package body common is

  -- Convert a Boolean to a std_logic.
  function BooleanToStdLogic(b : in boolean) return std_logic is
    variable s                :    std_logic;
  begin
    if b then
      s := '1';
    else
      s := '0';
    end if;
    return s;
  end function BooleanToStdLogic;

  -- Find the base 2 logarithm of a number.
  function Log2(v : in natural) return natural is
    variable n    :    natural;
    variable logn :    natural;
  begin
    n      := 1;
    for i in 0 to 128 loop
      logn := i;
      exit when (n >= v);
      n    := n * 2;
    end loop;
    return logn;
  end function Log2;

  -- Select one of two integers based on a Boolean.
  function IntSelect(s : in boolean; a : in integer; b : in integer) return integer is
  begin
    if s then
      return a;
    else
      return b;
    end if;
    return a;
  end function IntSelect;

  -- Select one of two reals based on a Boolean.
  function RealSelect(s : in boolean; a : in real; b : in real) return real is
  begin
    if s then
      return a;
    else
      return b;
    end if;
    return a;
  end function RealSelect;

  -- Convert a binary number to a graycode number.
  function BinaryToGray(b: in std_logic_vector) return std_logic_vector is
    variable g: std_logic_vector(b'range);
  begin
    for i in b'low to b'high-1 loop
      g(i) := b(i) XOR b(i+1);
    end loop;
    g(b'high) := b(b'high);
    return g;
  end function BinaryToGray;

  -- Convert a graycode number to a binary number.
  function GrayToBinary(g: in std_logic_vector) return std_logic_vector is
    variable b: std_logic_vector(g'range);
  begin
    b(b'high) := g(b'high);
    for i in g'high-1 downto g'low loop
      b(i) := b(i+1) XOR b(i);
    end loop;
    return b;
  end function GrayToBinary;

  -- Find the maximum of two integers.
  function IntMax(a: in integer; b: in integer) return integer is
  begin
    if a>b then
      return a;
    else
      return b;
    end if;
    return a;
  end function IntMax;

end package body common;
