---
program: CRTPLN3
language: PL/I
source: pli_src/code02.pli
analyzed: 2026-04-29
procedures:
  - name: CRTPLN3
    type: external
external_calls:
  - name: CSRIDAC
    linkage: ASSEMBLER
  - name: CSRVIEW
    linkage: ASSEMBLER
  - name: CSRSCOT
    linkage: ASSEMBLER
  - name: CSRSAVE
    linkage: ASSEMBLER
  - name: CSRREFR
    linkage: ASSEMBLER
files:
  - name: SYSPRINT
    type: OUTPUT
    organization: STREAM
---

# CRTPLN3 — z/OS Data Windowing Services (Hiperspace) Interface Demonstration

## Overview

CRTPLN3 is an IBM Enterprise PL/I for z/OS program that demonstrates the use of **z/OS Data Windowing Services** (also known as Window Services / Hiperspace Services). The program creates a temporary hiperspace object, maps windows of virtual storage into the object, writes computed data into two separate windows, saves and refreshes views, and then terminates access to the hiperspace object.

Data Windowing Services provide a mechanism for applications to efficiently manage large amounts of data by mapping segments (windows) of a data object into the application's address space. The hiperspace is a high-performance data space maintained by z/OS that allows rapid data access without traditional I/O overhead.

The program uses the following MVS callable services:

| Service | Purpose |
|---------|---------|
| **CSRIDAC** | Initiate or terminate access to a data object |
| **CSRVIEW** | Establish or end a view (map window into virtual storage) |
| **CSRSCOT** | Save (Scroll Out) changed data from a window to the object |
| **CSRSAVE** | Save data from a view to persistent object (declared but not called in main flow) |
| **CSRREFR** | Refresh a view from the object (discard local changes) |

## Program Flow

1. **Display start banner** — Output a header message to SYSPRINT indicating the start of Data Windowing Services validation.
2. **Initiate hiperspace access** — Call `CSRIDAC('BEGIN', ...)` to create a temporary hiperspace object named `'MY FIRST HIPERSPACE'` with UPDATE access mode and an initial size of 60 pages.
3. **Allocate working storage** — Allocate the BASED array `S` and compute the page-aligned starting offset (`ORIG`) within the allocated storage.
4. **Initialize window data** — Fill 20,480 elements of `S` starting at the page boundary with the value 99.
5. **Establish first view** — Call `CSRVIEW('BEGIN', ...)` to map the first window (pages 0–19) of the hiperspace into the allocated storage at the page boundary.
6. **Compute values in first window** — Overwrite each element with `I+1` (values 2 through 20,481).
7. **Save first window** — Call `CSRSCOT` to scroll out (save) the data in the first window back to the hiperspace object.
8. **End first view** — Call `CSRVIEW('END', ...)` with disposition `'RETAIN'` to end the view while retaining the data.
9. **Establish second view** — Call `CSRVIEW('BEGIN', ...)` to map the second window (pages 20–39) of the hiperspace into the same storage area.
10. **Compute values in second window** — Fill each element with `I-101` (values −100 through 20,379).
11. **Save second window** — Call `CSRSCOT` to save the second window's data to the hiperspace object.
12. **End second view** — Call `CSRVIEW('END', ...)` with `'RETAIN'` to end the second view.
13. **Re-establish first view** — Call `CSRVIEW('BEGIN', ...)` to map the first window again.
14. **Refresh first view** — Call `CSRREFR` to refresh the first window from the hiperspace object, restoring the previously saved data (values 2–20,481).
15. **End refreshed view** — Call `CSRVIEW('END', ...)` to end the refreshed first view.
16. **Terminate hiperspace access** — Call `CSRIDAC('END', ...)` to terminate access and destroy the temporary hiperspace object.
17. **Free storage** — Free the allocated BASED storage for `S`.

## Data Declarations

### Constants

| Variable | Value | Type | Description |
|----------|-------|------|-------------|
| `K` | 1024 | `FIXED BIN(31)` | One kilobyte (1,024 bytes) — declared but unused in logic |
| `PAGESIZE` | 4096 | `FIXED BIN(31)` | 4K page boundary size (z/OS uses 4,096-byte pages) |
| `OFFSET` | 0 | `FIXED BIN(31)` | Starting offset for the first window within the hiperspace object (page 0) |
| `WINDOW_SIZE` | 20 | `FIXED BIN(31)` | Window size in pages (20 pages = 80 KB) |
| `NUM_WIN_ELEM` | 20480 | `FIXED BIN(31)` | Number of 4-byte elements in a window (20 pages × 4,096 bytes ÷ 4 bytes = 20,480) |
| `OBJECT_SIZE` | 60 | `FIXED BIN(31)` | Total hiperspace object size in pages (60 pages = 240 KB) |

### Variables

| Variable | Type | Description |
|----------|------|-------------|
| `SP` | `POINTER` | Pointer to the BASED array `S`; set implicitly by `ALLOC S` |
| `ORIG` | `FIXED BIN(31)` | Computed offset to the first page-aligned element in `S` |
| `AD` | `FIXED BIN(31)` | Temporary variable holding the bit-pattern (address) of `SP` via `UNSPEC` |
| `I` | `FIXED BIN(31)` | Loop iteration variable |
| `HIGH_OFFSET` | `FIXED BIN(31)` | Output from `CSRIDAC` — current highest offset (size) of the object in pages |
| `NEW_HI_OFFSET` | `FIXED BIN(31)` | New maximum size of the object (used with `CSRSAVE`) |
| `RETURN_CODE` | `FIXED BIN(31)` | Return code from MVS callable services |
| `REASON_CODE` | `FIXED BIN(31)` | Reason code from MVS callable services |
| `OBJECT_ID` | `CHAR(8)` | Identifying token for the hiperspace object, returned by `CSRIDAC` |

### Structures

The program does not use PL/I structures or unions.

### BASED Array

```pli
DCL S(32767) BIN(31) FIXED BASED(SP);
```

`S` is a BASED array of 32,767 fullword (4-byte) binary integers, associated with pointer `SP`. The BASED attribute means storage is not allocated at declaration time; it is explicitly allocated via the `ALLOC` statement. The upper bound of 32,767 is the PL/I maximum for a single array dimension under certain compiler configurations. Only a subset of elements (starting at `ORIG`, spanning `NUM_WIN_ELEM` = 20,480 elements) is actively used as the window mapping area.

**Reference**: *PL/I Language Reference*, Part 2, pp. 248–251 — BASED attribute and locator qualification.

## External Interfaces

### Entry Declarations

All external entries are declared with `OPTIONS(ASSEMBLER)`, indicating they follow assembler (system) linkage conventions with no PL/I descriptors passed. This is required for calling MVS callable services from PL/I.

**Reference**: *PL/I Language Reference*, Part 1, p. 179 — `OPTIONS(ASSEMBLER)` has the same effect as `NODESCRIPTOR`. A PROCEDURE or ENTRY statement with `OPTIONS(ASSEMBLER)` will have `LINKAGE(SYSTEM)` unless a different linkage is explicitly specified.

#### CSRIDAC — Initiate/Terminate Data Object Access

```pli
DCL CSRIDAC ENTRY(CHAR(5), CHAR(9), CHAR(44), CHAR(3), CHAR(3),
                  CHAR(6), FIXED BIN(31), CHAR(8),
                  FIXED BIN(31), FIXED BIN(31), FIXED BIN(31))
                  OPTIONS(ASSEMBLER);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| OP_TYPE | `CHAR(5)` | Operation: `'BEGIN'` to initiate, `'END  '` to terminate |
| OBJECT_TYPE | `CHAR(9)` | Type of data object: `'TEMPSPACE'` (temporary hiperspace) |
| OBJECT_NAME | `CHAR(44)` | Name of the data object (up to 44 characters) |
| SCROLL_AREA | `CHAR(3)` | Whether scroll area is used: `'YES'` or `'NO '` |
| OBJECT_STATE | `CHAR(3)` | State: `'NEW'` for new object, `'OLD'` for existing |
| ACCESS_MODE | `CHAR(6)` | Access mode: `'UPDATE'` for read/write |
| OBJECT_SIZE | `FIXED BIN(31)` | Object size in pages (input on BEGIN) |
| OBJECT_ID | `CHAR(8)` | Identifying token (output on BEGIN, input on END) |
| HIGH_OFFSET | `FIXED BIN(31)` | Highest offset of the object in pages (output) |
| RETURN_CODE | `FIXED BIN(31)` | Return code (output) |
| REASON_CODE | `FIXED BIN(31)` | Reason code (output) |

#### CSRVIEW — Establish/End a View

```pli
DCL CSRVIEW ENTRY(CHAR(5), CHAR(8), FIXED BIN(31), FIXED BIN(31),
                  FIXED BIN(31), CHAR(6), CHAR(7),
                  FIXED BIN(31), FIXED BIN(31))
                  OPTIONS(ASSEMBLER);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| OP_TYPE | `CHAR(5)` | `'BEGIN'` or `'END '` |
| OBJECT_ID | `CHAR(8)` | Object token from CSRIDAC |
| OFFSET | `FIXED BIN(31)` | Offset in pages where the window starts within the object |
| WINDOW_SIZE | `FIXED BIN(31)` | Size of the window in pages |
| WINDOW_NAME | `FIXED BIN(31)` | Address of the virtual storage area to map (passed as the array element `S(ORIG)`) |
| USAGE | `CHAR(6)` | Access pattern: `'RANDOM'` or `'SEQ   '` |
| DISPOSITION | `CHAR(7)` | On END: `'REPLACE'` (replace view data) or `'RETAIN '` (keep data) |
| RETURN_CODE | `FIXED BIN(31)` | Return code (output) |
| REASON_CODE | `FIXED BIN(31)` | Reason code (output) |

#### CSRSCOT — Scroll Out (Save Changed Data)

```pli
DCL CSRSCOT ENTRY(CHAR(8), FIXED BIN(31), FIXED BIN(31),
                  FIXED BIN(31), FIXED BIN(31))
                  OPTIONS(ASSEMBLER);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| OBJECT_ID | `CHAR(8)` | Object token |
| OFFSET | `FIXED BIN(31)` | Starting page offset of data to save |
| SPAN | `FIXED BIN(31)` | Number of pages to save |
| RETURN_CODE | `FIXED BIN(31)` | Return code (output) |
| REASON_CODE | `FIXED BIN(31)` | Reason code (output) |

#### CSRSAVE — Save View Data to Object

```pli
DCL CSRSAVE ENTRY(CHAR(8), FIXED BIN(31), FIXED BIN(31),
                  FIXED BIN(31), FIXED BIN(31), FIXED BIN(31))
                  OPTIONS(ASSEMBLER);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| OBJECT_ID | `CHAR(8)` | Object token |
| OFFSET | `FIXED BIN(31)` | Starting offset |
| SPAN | `FIXED BIN(31)` | Number of pages |
| NEW_HI_OFFSET | `FIXED BIN(31)` | New highest offset of the object (output) |
| RETURN_CODE | `FIXED BIN(31)` | Return code (output) |
| REASON_CODE | `FIXED BIN(31)` | Reason code (output) |

#### CSRREFR — Refresh View from Object

```pli
DCL CSRREFR ENTRY(CHAR(8), FIXED BIN(31), FIXED BIN(31),
                  FIXED BIN(31), FIXED BIN(31))
                  OPTIONS(ASSEMBLER);
```

| Parameter | Type | Description |
|-----------|------|-------------|
| OBJECT_ID | `CHAR(8)` | Object token |
| OFFSET | `FIXED BIN(31)` | Starting offset to refresh |
| SPAN | `FIXED BIN(31)` | Number of pages to refresh |
| RETURN_CODE | `FIXED BIN(31)` | Return code (output) |
| REASON_CODE | `FIXED BIN(31)` | Reason code (output) |

### File Declarations

The program uses no explicit file declarations. The default `SYSPRINT` file is implicitly opened by the `PUT SKIP LIST` statement for stream output.

**Reference**: *PL/I Language Reference*, Part 2, p. 130 — If FILE is not specified in a PUT statement, `SYSPRINT` is the default output file.

## Detailed Code Walkthrough

### 1. Program Entry and Constant Declarations (Lines CSR00010–CSR00300)

```pli
CRTPLN3: PROCEDURE OPTIONS (MAIN);
```

The program is declared as the main entry point using `OPTIONS(MAIN)`. Six constants are declared with the `INIT` attribute to define the operational parameters for Data Windowing Services.

The BASED array `S(32767) BIN(31) FIXED BASED(SP)` provides a word-aligned overlay for the virtual storage window. The 32,767-element upper bound allows addressing up to 128 KB of storage in 4-byte increments.

### 2. External Entry Declarations (Lines CSR00320–CSR00810)

Five MVS callable services are declared as external entries with `OPTIONS(ASSEMBLER)`. This tells the PL/I compiler to use system linkage (no PL/I descriptors), which is required for calling assembler-linked MVS services. Each parameter's type matches the MVS service interface specification.

### 3. Banner Output (Lines CSR00860–CSR00880)

```pli
PUT SKIP LIST ('<< BEGIN DATA WINDOWING SERVICES INTERFACE VALIDATION >>');
PUT SKIP LIST (' ');
```

Writes a header to `SYSPRINT` using list-directed stream output. `PUT SKIP LIST` advances to the next line before writing.

### 4. Initiate Hiperspace Access (Lines CSR00900–CSR01010)

```pli
CALL CSRIDAC ('BEGIN', 'TEMPSPACE', 'MY FIRST HIPERSPACE',
              'YES', 'NEW', 'UPDATE', OBJECT_SIZE,
              OBJECT_ID, HIGH_OFFSET, RETURN_CODE, REASON_CODE);
```

Creates a **new temporary hiperspace** with:
- **TEMPSPACE**: The object type — a temporary data space that exists only for the duration of access.
- **'MY FIRST HIPERSPACE'**: A user-assigned name (padded to 44 characters).
- **'YES'**: Scroll area is available.
- **'NEW'**: A new object is being created.
- **'UPDATE'**: Read-write access.
- **OBJECT_SIZE = 60**: The object spans 60 pages (245,760 bytes).

On return, `OBJECT_ID` contains the 8-byte token identifying this hiperspace, and `HIGH_OFFSET` contains the highest valid offset.

### 5. Allocate and Align Storage (Lines CSR01030–CSR01080)

```pli
ALLOC S;
AD = UNSPEC(SP);
ORIG = MOD(AD, PAGESIZE);
IF ORIG ¬= 0 THEN
  ORIG = (PAGESIZE - ORIG) / 4;
ORIG = ORIG + 1;
```

This critical section:

1. **`ALLOC S`** — Allocates 131,068 bytes (32,767 × 4) of based storage and sets pointer `SP` to its address.
2. **`AD = UNSPEC(SP)`** — Extracts the raw bit pattern of the pointer as a `FIXED BIN(31)` integer, effectively converting the address to a numeric value. This is a common PL/I technique for address arithmetic.
3. **`ORIG = MOD(AD, PAGESIZE)`** — Computes the byte offset of the pointer within a 4K page boundary. If `AD` is already page-aligned, `MOD` returns 0.
4. **Page alignment calculation** — If not aligned (`ORIG ¬= 0`), calculates how many 4-byte array elements to skip to reach the next page boundary: `(4096 - byte_offset) / 4`.
5. **`ORIG = ORIG + 1`** — Converts from 0-based offset to 1-based PL/I array index.

After this, `S(ORIG)` is the first element at a 4K page boundary, which is required by Data Windowing Services for the window mapping area.

### 6. Initialize Window Area (Lines CSR01100–CSR01120)

```pli
DO I = 1 TO NUM_WIN_ELEM;
  S(I+ORIG-1) = 99;
END;
```

Fills 20,480 elements (80 KB) starting at the page boundary with the value 99. This pre-fills the area that will become the window mapping region.

### 7. First Window — View, Compute, Save, End (Lines CSR01140–CSR01450)

**Establish view:**
```pli
CALL CSRVIEW ('BEGIN', OBJECT_ID, OFFSET, WINDOW_SIZE,
              S(ORIG), 'RANDOM', 'REPLACE', RETURN_CODE, REASON_CODE);
```
Maps pages 0–19 of the hiperspace into the storage at `S(ORIG)`. The `'REPLACE'` disposition means the window area's current contents are replaced with the object's data (which is initially zeros for a new TEMPSPACE).

**Compute new values:**
```pli
DO I = 1 TO NUM_WIN_ELEM;
  S(I+ORIG-1) = I+1;
END;
```
Overwrites the window with values 2 through 20,481.

**Save to object:**
```pli
CALL CSRSCOT(OBJECT_ID, OFFSET, WINDOW_SIZE, RETURN_CODE, REASON_CODE);
```
Scrolls out (saves) the 20 pages of modified data from the window back to the hiperspace object.

**End view:**
```pli
CALL CSRVIEW ('END ', OBJECT_ID, OFFSET, WINDOW_SIZE,
              S(ORIG), 'RANDOM', 'RETAIN ', RETURN_CODE, REASON_CODE);
```
Ends the view with `'RETAIN'` disposition, keeping the data in the window area intact.

### 8. Second Window — View, Compute, Save, End (Lines CSR01470–CSR01790)

**Establish view at offset 20:**
```pli
CALL CSRVIEW ('BEGIN', OBJECT_ID, OFFSET+WINDOW_SIZE, WINDOW_SIZE,
              S(ORIG), 'RANDOM', 'REPLACE', RETURN_CODE, REASON_CODE);
```
Maps pages 20–39 of the hiperspace into the same storage area. `OFFSET+WINDOW_SIZE` = 0 + 20 = 20.

**Compute new values:**
```pli
DO I = 1 TO NUM_WIN_ELEM;
  S(I+ORIG-1) = I-101;
END;
```
Fills the window with values −100 through 20,379.

**Save and end** — Same pattern as the first window, scrolling out data and ending the view with `'RETAIN'`.

### 9. Re-establish and Refresh First Window (Lines CSR01810–CSR02080)

```pli
CALL CSRVIEW ('BEGIN', OBJECT_ID, OFFSET, WINDOW_SIZE,
              S(ORIG), 'RANDOM', 'REPLACE', RETURN_CODE, REASON_CODE);

CALL CSRREFR (OBJECT_ID, OFFSET, WINDOW_SIZE, RETURN_CODE, REASON_CODE);
```

Re-maps the first window (pages 0–19) and then **refreshes** it from the hiperspace object using `CSRREFR`. The refresh discards any local modifications and restores the data that was previously saved via `CSRSCOT` (values 2–20,481). This demonstrates the ability to restore a saved view.

The view is then ended with `'RETAIN'`.

### 10. Terminate Access and Cleanup (Lines CSR02100–CSR02260)

```pli
CALL CSRIDAC ('END  ', 'TEMPSPACE', 'MY FIRST HIPERSPACE ENDS HERE ',
              'YES', 'NEW', 'UPDATE', WINDOW_SIZE,
              OBJECT_ID, HIGH_OFFSET, RETURN_CODE, REASON_CODE);
FREE S;
END CRTPLN3;
```

Calls `CSRIDAC('END', ...)` to terminate access to the temporary hiperspace, which destroys the object (since it is `TEMPSPACE`). The BASED storage is then freed and the program ends.

## PL/I Language Constructs

### PROCEDURE OPTIONS(MAIN)

Declares the procedure as the program's main entry point. The Language Environment runtime calls this procedure on program startup.

**Reference**: *PL/I Language Reference*, Part 1, p. 143 — PROCEDURE statement and OPTIONS(MAIN).

### BASED Attribute

The `BASED(SP)` attribute on array `S` indicates that `S` does not have its own storage; it overlays storage identified by pointer `SP`. The `ALLOC S` statement allocates storage and sets `SP`.

**Reference**: *PL/I Language Reference*, Part 2, pp. 248–251 — "A based variable can be used to refer to any generation of data when qualified by an appropriate locator reference."

### POINTER (PTR) Attribute

`SP` is declared as `PTR` — a locator variable that holds the address of a generation of the BASED variable `S`. Under `LP(32)`, `POINTER` is 4 bytes (fullword-aligned); under `LP(64)`, it is 8 bytes.

**Reference**: *PL/I Language Reference*, Part 2, p. 251 — POINTER variable and attribute.

### UNSPEC Built-in Function

`UNSPEC(SP)` returns the internal bit representation of the pointer as a bit string. Assigning this to `AD` (a `FIXED BIN(31)`) converts the address to a numeric value for arithmetic operations (page alignment calculation).

**Reference**: *PL/I Language Reference*, Part 3, p. 582 — "UNSPEC returns a bit string that is the internal coded form of x."

### MOD Built-in Function

`MOD(AD, PAGESIZE)` returns the modular remainder of the address divided by 4096, determining how many bytes past a page boundary the storage address falls.

**Reference**: *PL/I Language Reference*, Part 3, pp. 562–563 — "MOD returns the smallest nonnegative value, R, such that (x−R) is divisible by y."

### INIT (INITIAL) Attribute

All constants are declared with `INIT(value)`, which specifies the initial value assigned when storage is allocated.

**Reference**: *PL/I Language Reference*, Part 2, pp. 269–271 — "The INITIAL attribute specifies an initial value or values assigned to a variable at the time storage is allocated to it."

### FIXED BIN(31)

The `FIXED BINARY(31)` attribute declares a signed fullword (4-byte) binary integer with 31 bits of precision, capable of holding values from −2,147,483,648 to +2,147,483,647. This maps directly to the z/Architecture 32-bit general register format.

**Reference**: *PL/I Language Reference*, Part 1, p. 76 — Binary fixed-point data.

### CHAR(n) — Fixed-Length Character String

Character string parameters in the entry declarations (e.g., `CHAR(5)`, `CHAR(8)`, `CHAR(44)`) specify fixed-length character strings. These match the parameter formats expected by the MVS callable services.

**Reference**: *PL/I Language Reference*, Part 1, p. 81 — CHARACTER attribute.

### OPTIONS(ASSEMBLER)

Specifies that the external entry follows assembler linkage conventions. This has the same effect as `NODESCRIPTOR` (no PL/I parameter descriptors are passed). The linkage defaults to `LINKAGE(SYSTEM)`.

**Reference**: *PL/I Language Reference*, Part 1, p. 179 — "The ASSEMBLER option has the same effect as NODESCRIPTOR. A PROCEDURE or ENTRY statement that specifies OPTIONS(ASSEMBLER) will have LINKAGE(SYSTEM) unless a different linkage is explicitly specified."

### ALLOC / FREE Statements

`ALLOC S` allocates storage for the BASED variable `S` and sets its associated pointer `SP`. `FREE S` releases that storage.

**Reference**: *PL/I Language Reference*, Part 2, pp. 252–254 — ALLOCATE and FREE statements for based variables.

### PUT SKIP LIST

List-directed stream output. `SKIP` advances to the next line. `LIST` writes the expression values with automatic formatting to the default file `SYSPRINT`.

**Reference**: *PL/I Language Reference*, Part 2, pp. 300, 350 — PUT statement and SKIP option.

### ¬= (NOT EQUAL) Operator

The `¬=` operator is the PL/I not-equal comparison operator. In this program: `IF ORIG ¬= 0 THEN` tests whether the address is not page-aligned.

### DO Loop

`DO I = 1 TO NUM_WIN_ELEM` is a controlled iterative DO group used to fill window elements with computed values.

## Error Handling

The program **does not implement explicit error handling**. Specifically:

- **No return code checking**: `RETURN_CODE` and `REASON_CODE` are declared and populated by each MVS callable service, but their values are never tested. In a production program, each call should check `RETURN_CODE` for non-zero values indicating errors.
- **No ON conditions**: There are no `ON ERROR`, `ON ENDFILE`, or other condition handlers.
- **No SYSPRINT diagnostics**: Return codes and reason codes are not displayed.

In a production implementation, each MVS service call should be followed by:
```pli
IF RETURN_CODE ¬= 0 THEN DO;
  PUT SKIP LIST ('Service failed, RC=', RETURN_CODE, 'RSN=', REASON_CODE);
  /* appropriate recovery or termination */
END;
```

## Dependencies

### MVS Callable Services (SYS1.CSSLIB)

The program depends on the following z/OS Data Windowing Services stubs from `SYS1.CSSLIB`:

| Service | Module | Purpose |
|---------|--------|---------|
| CSRIDAC | SYS1.CSSLIB | Initiate/terminate data object access |
| CSRVIEW | SYS1.CSSLIB | Establish/end a view |
| CSRSCOT | SYS1.CSSLIB | Scroll out (save changed data) |
| CSRSAVE | SYS1.CSSLIB | Save data to object |
| CSRREFR | SYS1.CSSLIB | Refresh view from object |

### Language Environment

The program requires the z/OS Language Environment runtime (`CEE.SCEERUN`) for PL/I program initialization, storage management, and I/O services.

### External Programs

None — the program is self-contained.

### Include Files

None — no `%INCLUDE` directives.

### Data Sets

No user data sets are accessed. The temporary hiperspace object `'MY FIRST HIPERSPACE'` is entirely in-memory.

## JCL

### Compile and Link-Edit

```jcl
//PLIJOB   JOB
//*
//*  PL/I Compile and Linkedit
//*
//GO       EXEC PLIXCL
//PLI.SYSIN DD DSN=WINDOW.XAMPLE.LIB(CRTPLN3),DISP=SHR
//LKED.SYSLMOD DD DSN=WINDOW.USER.LOAD,UNIT=3380,VOL=SER=VM2TSO,
// DISP=SHR
//LKED.SYSIN DD *
  LIBRARY  IN(CSRSCOT,CSRSAVE,CSRREFR,CSRSAVE,CSRVIEW,CSRIDAC)
  NAME CRTPLN3(R)
/*
//*     SYS1.CSSLIB is source of CSR stubs
//LKED.IN     DD DSN=SYS1.CSSLIB,DISP=SHR
```

**Key points:**
- **PLIXCL**: IBM-supplied cataloged procedure that compiles PL/I source and link-edits the object module.
- **PLI.SYSIN**: Points to the PL/I source member `CRTPLN3` in `WINDOW.XAMPLE.LIB`.
- **LKED.SYSLMOD**: Output load module library.
- **LIBRARY IN(...)**: Link-editor control statement to include the Data Windowing Services stubs (`CSRSCOT`, `CSRSAVE`, `CSRREFR`, `CSRVIEW`, `CSRIDAC`) from `SYS1.CSSLIB`.
- **NAME CRTPLN3(R)**: Names the load module and marks it as reentrant.

### Execute

```jcl
//PLIRUN   JOB MSGLEVEL=(1,1)
//*
//*   EXECUTE A PL/I TESTCASE
//*
//GO       EXEC PGM=CRTPLN3
//STEPLIB  DD  DSN=WINDOW.USER.LOAD,DISP=SHR,
// UNIT=3380,VOL=SER=VM2TSO
//SYSLIB   DD  DSN=CEE.SCEERUN,DISP=SHR
//SYSABEND DD SYSOUT=*
//SYSLOUT  DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
```

**Key points:**
- **PGM=CRTPLN3**: Executes the compiled load module.
- **STEPLIB**: Points to the load library containing the CRTPLN3 module.
- **SYSLIB**: Language Environment runtime library (`CEE.SCEERUN`).
- **SYSABEND**: Destination for abnormal termination dumps.
- **SYSPRINT**: Output destination for `PUT` statement output (directed to JES spool).
- **MSGLEVEL=(1,1)**: Display all JCL statements and messages for diagnostics.
