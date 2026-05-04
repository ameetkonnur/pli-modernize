# PL/I Language Reference Skill

Use this skill when you need to look up or verify PL/I language constructs.

## MCP Server Usage

The `custom-pli-mcp` server has indexed the following IBM Enterprise PL/I for z/OS 6.2 documentation:

| Document | Indexed Parts | Content |
|----------|--------------|---------|
| Language Reference | Parts 1–4 (pp. 1–766) | Syntax, attributes, built-in functions, statements, conditions |
| Programming Guide | Parts 1–3 (pp. 1–562) | Compiler options, I/O, interfacing, optimization, examples |
| Messages and Codes | Full document | Compile-time and runtime messages, error codes, diagnostics |
| Compiler and Run-Time Migration Guide | Full document | Migration from older compilers, changed behaviors, new compiler messages |
| z/OS LE Programming Guide | Parts 1–3 (pp. 1–602) | LE runtime environment, condition handling, storage management, interlanguage communication, CEE callable services |

### Search Strategy

1. **Start with `search`** using specific PL/I keywords (e.g., `"UNSPEC built-in function bit string"`)
2. **Narrow results** by including the construct category (e.g., `"BASED attribute storage class pointer"`)
3. **Use `fetch`** with the document title and page number from search results for full content
4. **Cross-reference** Language Reference for syntax and Programming Guide for usage examples

### Common Lookup Patterns

| What You Need | Search Query Pattern |
|---------------|---------------------|
| Built-in function | `"<FUNC_NAME> built-in function returns"` |
| Data attribute | `"<ATTR> attribute declaration"` |
| Statement syntax | `"<STMT> statement syntax"` |
| Compiler option | `"<OPT> compiler option"` |
| Condition handling | `"<COND> condition ON-unit"` |
| I/O operation | `"<OP> file record stream"` |
| Compiler message | `"IBM<nnnn> message"` |
| Migration guidance | `"migration changed behavior <topic>"` |
| LE callable service | `"CEE<name> callable service"` |
| LE runtime option | `"<OPT> runtime option Language Environment"` |

## Key PL/I Concepts Quick Reference

### Data Types
- `FIXED BIN(p)` — Binary integer, p bits precision (15 = halfword, 31 = fullword, 63 = doubleword)
- `FIXED DEC(p,q)` — Packed decimal, p digits, q decimal places
- `FLOAT BIN(p)` / `FLOAT DEC(p)` — Floating point
- `CHAR(n)` — Fixed-length character string
- `CHAR(n) VARYING` — Variable-length character string (VARCHAR equivalent)
- `BIT(n)` — Bit string
- `POINTER` — Address locator (4 bytes under LP(32), 8 bytes under LP(64))
- `OFFSET` — Offset within an AREA
- `PICTURE` — Edited numeric/character format

### Storage Classes
- `AUTOMATIC` — Stack-allocated, default for block-scoped variables
- `STATIC` — Allocated once, persists for program duration
- `BASED` — Heap-allocated via ALLOCATE, addressed through pointer
- `CONTROLLED` — Stack of allocations, push/pop semantics
- `DEFINED` — Overlays another variable's storage

### Key Built-in Functions
- `ADDR(x)` — Address of x
- `UNSPEC(x)` — Bit-string representation of x
- `MOD(x,y)` — Modular remainder (always nonneg)
- `REM(x,y)` — Remainder (can be negative)
- `LENGTH(x)` — Length of string x
- `SUBSTR(x,i,j)` — Substring extraction
- `INDEX(x,y)` — Position of y in x
- `TRIM(x)` — Remove leading/trailing blanks
- `VERIFY(x,y)` — Position of first char in x not in y
- `NULL()` — PL/I null pointer
- `SYSNULL()` — System null pointer
- `STG(x)` — Storage size in bytes
- `ALLOCATION(x)` — Number of current allocations

### Condition Handling
- `ON condition action;` — Establish handler
- `SIGNAL condition;` — Raise condition programmatically
- `REVERT condition;` — Remove handler
- Key conditions: `ENDFILE`, `KEY`, `CONVERSION`, `OVERFLOW`, `UNDERFLOW`, `ZERODIVIDE`, `STRINGRANGE`, `SUBSCRIPTRANGE`, `SIZE`, `AREA`, `STORAGE`, `ERROR`
