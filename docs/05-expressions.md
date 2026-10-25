[← Index](../README.md) · [← Variables](04-variables.md) · Next: [Conditional statements →](06-conditionals.md)

# 5. Expressions (SET /A)

`SET /A` is the only expression evaluator: **32-bit signed integer** arithmetic and bitwise logic. There is no floating point, no comparison operator and no string expression.

- [Syntax](#syntax)
- [Operators and precedence](#operators-and-precedence)
- [Numbers: decimal, hex, octal](#numbers-decimal-hex-octal)
- [Variables in expressions](#variables-in-expressions)
- [Integer semantics](#integer-semantics)
- [Errors](#errors)
- [Recipes](#recipes)
- [Pitfalls](#pitfalls)

---

## Syntax

```bat
set /a "total=a + b * 2"
set /a "i+=1"
set /a "x=1, y=x+1, z=(x+y)<<2"       & rem comma: several assignments, left to right
set /a "r=(n=5, n*n)"                  & rem value of a comma group is the last expression
```

- **Quote the whole expression.** Otherwise `<<`, `>>`, `&`, `|`, `^` are taken as redirection/command operators.
- In a batch file, `%` is `%%`: `set /a "rem=n %% 4"`.
- Whitespace is free inside the expression.
- At the interactive prompt `set /a` prints the result; **in a batch file it prints nothing**.

## Operators and precedence

From highest to lowest (same as C):

| Operators | Meaning |
|---|---|
| `( )` | Grouping |
| `!` `~` `-` `+` | Logical NOT (0 → 1, non-zero → 0), bitwise NOT, unary minus, unary plus |
| `*` `/` `%` | Multiply, divide (truncates towards zero), remainder (sign of dividend) |
| `+` `-` | Add, subtract |
| `<<` `>>` | Shift left, arithmetic shift right (sign-extending) |
| `&` | Bitwise AND |
| `^` | Bitwise XOR |
| `\|` | Bitwise OR |
| `=` `*=` `/=` `%=` `+=` `-=` `&=` `^=` `\|=` `<<=` `>>=` | Assignment |
| `,` | Expression separator |

Verified results: `-7/2` = -3, `-7%2` = -1, `-16>>2` = -4, `~0` = -1, `5^3` = 6, `!5` = 0, `1<<31` = -2147483648.

There are **no** comparison (`<`, `==`), logical AND/OR (`&&`, `||`), ternary, increment (`++`) or exponent operators — `set /a "x=(3>2)"` is a syntax error (*Missing operator*). Compare with [`IF ... GTR`](07-condition-tests.md#comparison-operators) instead, or use arithmetic tricks (below).

## Numbers: decimal, hex, octal

| Literal | Value |
|---|---|
| `42` | decimal |
| `0x2A` | hexadecimal |
| `052` | **octal** (leading zero!) |
| `08`, `09` | **error** — *Invalid number* |

Leading zeros bite with dates and times (`%TIME:~3,2%` → `08`). Strip them, or use the "prefix 1 and subtract" trick:

```bat
set "mm=08"
set /a "m=1%mm% - 100"        & rem 108 - 100 = 8 (for exactly 2 digits)
set /a "m=10%mm% %% 100"      & rem 1008 %% 100 = 8 - also 2 digits
for /f "tokens=* delims=0" %%A in ("%mm%") do set "m=%%A"   & rem strip zeros (empty if "00")
if not defined m set "m=0"
```

## Variables in expressions

- Names can be used **without** `%`: `set /a "x=y+1"`. This reads the current value, so it is correct inside blocks without delayed expansion. Prefer it.
- An undefined or non-numeric variable counts as **0**.
- Values are parsed as numbers with the literal rules above: a variable containing `010` is 8; `08` gives an error.
- Values are **not** evaluated recursively: if `expr=five+1`, `set /a "x=expr"` is 0, not 6 (verified).
- `%var%` inside the expression is substituted as text first (phase 1) — handy for building expressions, risky for untrusted values.

```bat
set /a "count+=1"                     & rem fine inside a FOR block
set "op=*"
set /a "r=6 %op% 7"                   & rem r=42 - textual substitution
```

> `set "op=*" & set /a "r=6 %op% 7"` on **one** line fails: `%op%` is expanded when the line is parsed, before the first `set` runs (verified: *Missing operator*).

## Integer semantics

- Range −2,147,483,648 … 2,147,483,647. Arithmetic **wraps silently**: `2147483647+1` = −2147483648.
- A **literal** outside the range is an error (*Numbers are limited to 32-bits of precision*).
- Division by zero is an error (*Divide by zero error*).
- No floating point. Use fixed-point: scale by 100 (or 1000), compute, then format.

## Errors

On error `SET /A` prints a message to stderr, leaves the target unchanged, and sets a non-zero `ERRORLEVEL` (observed: `1073750993` for divide by zero, `1073750992` for out-of-range numbers). Test with `if errorlevel 1` or `||`:

```bat
set /a "n=%input%" 2>nul || (echo Not a number: %input% & exit /b 1)
```

That catches malformed input such as `2x`, but accepts expressions (`2*3`) and silently treats a word such as `abc` as an (undefined) variable name, i.e. 0 (verified). To validate digits only:

```bat
for /f "delims=0123456789" %%A in ("%input%") do (echo Not a number & exit /b 1)
```

## Recipes

**Fixed-point division with 2 decimals:**

```bat
set /a "cents=total*100/count"
set /a "whole=cents/100, frac=cents%%100"
if %frac% lss 10 set "frac=0%frac%"
echo Average: %whole%.%frac%
```

**Percentage:** `set /a "pct=done*100/all"` (multiply first to avoid truncating to 0).

**Min / max / abs / sign without IF:**

```bat
set /a "d=a-b, max=a-((d>>31)&d)"          & rem max(a,b) (when a-b does not overflow)
set /a "min=b+((d>>31)&d)"
set /a "abs=(x^(x>>31))-(x>>31)"
set /a "sign=(x>>31)|(-x>>31&1)"           & rem -1, 0 or 1 (for x > -2147483648)
```

**Boolean from a comparison** — use `IF`:

```bat
set "isBig=0" & if %size% gtr 1048576 set "isBig=1"
```

**Random number in a range** (`%RANDOM%` is 0–32767):

```bat
set /a "dice=%RANDOM% %% 6 + 1"
set /a "big=(%RANDOM% << 15) | %RANDOM%"    & rem 0..1073741823
```

**Bit flags:**

```bat
set /a "FLAG_A=1, FLAG_B=2, FLAG_C=4"
set /a "flags=FLAG_A|FLAG_C"
set /a "hasB=(flags>>1)&1"
```

**Hex output** (no built-in formatting):

```bat
set "hex=" & set /a "n=255"
set "digits=0123456789ABCDEF"
:hexloop
set /a "d=n & 15, n>>=4"
call set "hex=%%digits:~%d%,1%%%hex%"
if %n% gtr 0 goto :hexloop
echo 0x%hex%
```

## Pitfalls

- Unquoted expressions: `set /a x=1<<4` fails with *"1<< was unexpected at this time"* because `<` is redirection — quote it.
- `%` must be `%%` in batch files.
- Leading zero = octal; `08`/`09` are errors.
- Silent 32-bit wrap-around; no floats; truncating division.
- `set /a` inside a block with `%var%` operands uses stale values — use bare names.
- `SET /A` with no comparison operators: `(a>b)` is a syntax error.

---

See also: [Condition tests](07-condition-tests.md) · [Variables](04-variables.md)
