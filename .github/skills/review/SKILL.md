# Code Review Skill

Use this skill when reviewing PL/I code against best practices.

## Review Severity Levels

| Level | Icon | Meaning | Action Required |
|-------|------|---------|-----------------|
| **Critical** | ❌ | Will cause runtime failure, data corruption, or security issue | Must fix before production |
| **Warning** | ⚠️ | May cause problems under specific conditions | Should fix |
| **Info** | ℹ️ | Improvement suggestion, not a defect | Nice to have |
## MCP Reference Documents

When reviewing code, leverage all indexed documents:
- **Language Reference** — verify correct syntax and semantics of constructs
- **Programming Guide** — check compiler options and I/O patterns
- **Messages and Codes** — look up specific compiler messages (IBM*nnnn*) to cite in findings
- **Migration Guide** — identify deprecated patterns and recommend modern alternatives
- **LE Programming Guide** — verify condition handling, storage management, interlanguage calling conventions, and CEE callable service usage
## PL/I Best Practices Checklist

All rules below are sourced from or verified against IBM Enterprise PL/I for z/OS 6.2 documentation (indexed in the MCP) and IBM's online Programming Guide. Use the MCP `search` tool to cite specific references when reporting findings.

### Recommended Compiler Options Baseline

When reviewing, check whether the program would compile cleanly under this quality-enforcing baseline (from IBM Programming Guide and Migration Guide):

```
RULES(ANS NOLAXDCL NOLAXCTL NOLAXENTRY NOGLOBALDO NOLAXRETURN NOUNSET NOYY NOSELFASSIGN)
```

| RULES Suboption | What It Enforces | Source |
|-----------------|------------------|--------|
| `NOLAXDCL` | All variables must be explicitly declared — catches typos, implicit declarations | Migration Guide p.93 |
| `NOLAXCTL` | CONTROLLED extents declared as constant must truly be constant | Migration Guide p.93 |
| `NOLAXENTRY` | All external entries must have prototyped declarations | Programming Guide p.123 |
| `NOGLOBALDO` | DO loop control variables must not be declared in parent blocks | Programming Guide p.130 |
| `NOLAXRETURN` | RETURN expressions must match RETURNS attribute | Programming Guide p.127 |
| `NOUNSET` | Flags use of potentially uninitialized AUTOMATIC variables | Programming Guide p.133 |
| `NOYY` | Flags 2-digit year usage (DATE attribute without pattern, Y4DATE, etc.) | Programming Guide p.133 |
| `NOSELFASSIGN` | Flags self-assignments (`x = x`) — usually a bug | Programming Guide p.133 |
| `ANS` | Avoids scaled FIXED BINARY results — better performance | Programming Guide p.130 |

---

### 1. Error Handling (Weight: Critical)

**Must Do:**
- Check RETURN_CODE after every CALL to external services
- Define ON ENDFILE before first READ
- Handle KEY condition for keyed file access
- Handle CONVERSION for external input parsing
- Enable STRINGRANGE/SUBSCRIPTRANGE during development (via PREFIX compiler option)
- Include `ON ERROR SYSTEM;` to prevent unhandled conditions from silently continuing (IBM2621)
- Use LE condition handling (CEEHDLR) for registering user-written condition handlers when ON-units are insufficient

**Anti-Patterns:**
```pli
/* BAD: No return code check */
CALL CSRIDAC('BEGIN', ...RETURN_CODE, REASON_CODE);
/* continues regardless of RETURN_CODE value */

/* GOOD: Check return code */
CALL CSRIDAC('BEGIN', ...RETURN_CODE, REASON_CODE);
IF RETURN_CODE ¬= 0 THEN DO;
  PUT SKIP LIST('CSRIDAC failed: RC=' || TRIM(RETURN_CODE));
  SIGNAL ERROR;
END;
```

---

### 2. Memory Management (Weight: Critical)

**Must Do:**
- Match every ALLOCATE with FREE
- FREE before RETURN on error paths
- Validate pointer is not NULL before dereferencing BASED variable
- Handle STORAGE condition for ALLOCATE
- Use LE heap storage services (CEEGTST/CEEFRST) when interoperating with other LE languages

**Anti-Patterns:**
```pli
/* BAD: Memory leak on error path */
ALLOCATE BUFFER;
CALL PROCESS(BUFFER, RC);
IF RC ¬= 0 THEN RETURN;  /* BUFFER never freed! */
FREE BUFFER;

/* GOOD: Free on all paths */
ALLOCATE BUFFER;
CALL PROCESS(BUFFER, RC);
IF RC ¬= 0 THEN DO;
  FREE BUFFER;
  RETURN;
END;
FREE BUFFER;
```

---

### 3. Data Declarations (Weight: Warning)

**Must Do:**
- Explicit declarations for all variables — compile with `RULES(NOLAXDCL)`
- Use `FIXED BIN(31)` not `FIXED BIN(15)` unless halfword API required
- CHAR lengths should match actual data, not be oversized
- PICTURE specs should match input format
- Use `VALUE` attribute instead of `STATIC INIT` for named constants (IBM2812, IBM2672)
- Prototype all external entries — compile with `RULES(NOLAXENTRY)`

**Anti-Patterns:**
```pli
/* BAD: Implicit declaration, wrong precision */
X = X + 1;  /* X not declared — gets DEFAULT attributes */

/* GOOD: Explicit */
DCL X FIXED BIN(31) INIT(0);
X = X + 1;

/* BAD: STATIC INIT for constants — runtime table build, poor performance */
DCL UPPER CHAR(26) STATIC INIT('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
C = TRANSLATE(C, UPPER, LOWER);

/* GOOD: VALUE attribute — compile-time constant, optimal code */
DCL UPPER CHAR(26) VALUE('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
C = TRANSLATE(C, UPPER, LOWER);
```

**Source**: IBM Programming Guide "Named constants versus static variables"; Migration Guide IBM2812.

---

### 4. Structured Programming (Weight: Warning)

**Must Do:**
- Avoid GOTO — use DO WHILE, SELECT/WHEN, internal procedures
- GOTO to a label in another block or via a label variable severely limits compiler optimization
- If label arrays are needed, declare them STATIC (compiler assumes CONSTANT)
- Keep procedures under 100 statements
- Prefer PACKAGEs over deeply nested PROCEDUREs for better optimization
- Use meaningful label names if GOTO is unavoidable

**Anti-Patterns:**
```pli
/* BAD: Spaghetti GOTO */
IF X > 0 THEN GOTO PROCESS_A;
GOTO PROCESS_B;
PROCESS_A: ...
GOTO DONE;
PROCESS_B: ...
DONE: ...

/* GOOD: Structured */
SELECT;
  WHEN(X > 0) CALL PROCESS_A;
  OTHERWISE CALL PROCESS_B;
END;
```

**Source**: IBM Programming Guide "GOTO statements"; "PACKAGEs versus nested PROCEDUREs".

---

### 5. Performance (Weight: Info)

**Watch For:**

| Issue | Recommendation | Source |
|-------|---------------|--------|
| PICTURE as DO loop control variable | Use `FIXED BIN(31)` — much faster loop code | IBM2811, IBM2675 |
| DO control variable from parent block | Declare loop variable locally with `AUTOMATIC` | `RULES(NOGLOBALDO)` |
| DO control variable is member of structure/array | Use standalone `AUTOMATIC FIXED BIN(31)` variable | Programming Guide "Loop control variables" |
| STATIC INIT for constants used in TRANSLATE/VERIFY | Use `VALUE` attribute — avoids runtime table build | IBM2812 |
| String concatenation in tight loops | Use SUBSTR assignment instead | Programming Guide |
| Unnecessary FIXED BIN ↔ FIXED DEC conversion | Keep operands in same type; use DECIMAL() built-in if needed | IBM2809 |
| CHAR(*) parameters | Causes descriptor overhead; prefer explicit lengths | Programming Guide |
| DEFINED overlays | Replace with UNION — compiler generates better code | Programming Guide "DEFINED versus UNION" |
| Passing label variables out of PL/I | Avoid — "very unwise" per IBM; hinders optimization | IBM2617, Programming Guide |
| GET DATA / PUT DATA in production | Remove — use GET/PUT LIST or EDIT for production code | Programming Guide "DATA-directed I/O" |
| Input-only parameters not marked NONASSIGNABLE | Mark NONASSIGNABLE or INONLY to enable optimization | Programming Guide "Input-only parameters" |
| PLIMOVE not used for non-overlapping BASED string copies | Use PLIMOVE when source/target cannot overlap | Programming Guide "String assignments" |
| Overuse of PL/I conditions | All condition handling is expensive; use only where appropriate | Migration Guide p.137 |
| Boolean compared with non-BIT(1) | Use `BIT(1) VALUE('1'B)` for comparison constants | IBM2804 |

---

### 6. Maintainability (Weight: Warning)

**Must Do:**
- Meaningful variable and procedure names
- Comments explain WHY, not just WHAT
- Complex logic broken into internal procedures
- Magic numbers replaced with named constants (using `VALUE` attribute)
- Consistent indentation and formatting
- No unreachable code
- Do not write more than one statement on a line
- Do not split a language element across lines — use concatenation (`||`) for long strings

**Source**: IBM Language Reference p.58 "Program element conventions".

---

### 7. Security & Robustness (Weight: Critical)

**Must Do:**
- Input validation before processing
- Buffer overrun protection — enable STRINGRANGE, SUBSCRIPTRANGE via PREFIX compiler option
- No hardcoded credentials or sensitive data
- Proper handling of CONVERSION condition for external input
- SIZE condition enabled where arithmetic overflow is possible
- Validate pointer values before BASED dereference
- Do not pass labels to external routines (security and correctness risk)

---

### 8. z/OS Integration (Weight: Warning)

**Must Do:**
- Correct linkage conventions: `OPTIONS(ASM)` for assembler calls, prototyped ENTRY for all external calls
- Proper use of MVS callable services — verify signatures via MCP search
- LE runtime options appropriate for the application (TRAP, STORAGE, HEAP, etc.)
- JCL parameters match program expectations
- Correct AMODE/RMODE for the execution environment
- Use BLKSIZE(0) for output files that can be blocked — DFSMS determines optimal block size
- Use LE Library Routine Retention (LRR) for better CPU performance in repeated invocations
- Put commonly used LE routines in (E)LPA for reduced LOADs/DELETEs
- Use AMODE(31) when possible to avoid AMODE switching — specify ALL31(ON)

**Source**: Migration Guide p.137 "Performance considerations".

## Scoring Guide

| Category | ✅ Pass | ⚠️ Warning | ❌ Fail |
|----------|---------|------------|---------|
| Error Handling | All external calls checked | Some calls unchecked | No error handling at all |
| Memory Management | All ALLOC/FREE paired | Leak only on obscure error path | Obvious leaks |
| Data Declarations | All explicit, correct types | Minor type issues | Implicit declarations |
| I/O Operations | All files opened/closed, ENDFILE handled | Missing CLOSE on some paths | No ENDFILE handler |
| Performance | Efficient patterns used | Minor inefficiencies | O(n²) or worse when avoidable |
| Maintainability | Well-structured, commented | Adequate | Uncommented, spaghetti |
| Security | Input validated, bounds checked | Partial validation | No validation |
| z/OS Integration | Correct linkage, JCL matches | Minor JCL issues | Wrong linkage conventions |
