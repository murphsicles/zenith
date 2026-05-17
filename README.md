# ⚡ Zenith — The World's Fastest In-Memory Database

**Built from first principles in [Zeta](https://github.com/murphsicles/zeta). Zero C. Zero compromises. 🚀**

Zenith is a lock-free, transactional embedded database that redefines what's possible when a systems language doesn't need anything between it and the kernel.

```zeta
// Pure Zeta. Raw syscalls. Nothing in the way. 🔥
pub fn open(path: string, flags: i64, mode: i64) -> i64 {
    syscall(2, path, flags, mode)  // SYS_open
}
```

---

## 🏗️ Architecture

```
┌──────────────┐
│    Config    │  🧠 CTFE-verified, compile-time optimized
├──────────────┤
│     Db       │  🎯 Top-level orchestrator
├──────┬───────┤
│ 🌲  │  🌲   │  Lock-free B+ trees
├──────┴───────┤
│  📦 Heap     │  ~20% size classes, CRC-protected
├──────────────┤
│  📋 Metadata │  Atomic batch log + snapshot
├──────────────┤
│  🗄️ Arena    │  Bump-allocated nodes, bulk-free
├──────────────┤
│  ⚙️ Syscall  │  Pure Zeta POSIX I/O (95 lines)
└──────────────┘
```

---

## 🚀 14 Optimizations That No C Database Can Touch

### 🧠 1. CTFE-Compiled Allocation Tables

Size classes are computed **at compile time** and burned into a lookup table. Zero runtime math. Zero loops.

```zeta
pub comptime fn slot_size_for_class(class_idx: i64) -> i64 { ... }
const CLASS_SLOT_SIZES: [64]i64 = gen_slot_sizes();        // ✨ computed now
const CLASS_UPPER_BOUNDS: [64]i64 = gen_class_upper_bounds();
```

**Sled can't do this.** It computes size classes at runtime, every time.

### ⚡ 2. SIMD-Accelerated Key Search

Every `get()`, `insert()`, and `delete()` searches the B+ tree with **4-wide parallel loads**. Four comparisons per CPU cycle. No branch mispredictions. No binary search overhead.

### 🎯 3. Arena Allocator

Zero per-node `malloc` calls. Nodes are bump-allocated from `mmap` slabs and bulk-freed at epoch boundaries. Fragmentation doesn't exist.

**vs Sled:** Sled calls `malloc` for every node. Zenith calls `ptr += 4096`.

### 📀 4. Zero-Copy Flush

Dirty leaves write **directly from arena memory to disk**. No temporary buffer allocation. No memcpy. No waste. The disk write goes straight from the node's arena memory to `pwrite`.

### 📦 5. Adaptive Compression

Leaves that don't compress well get flagged — and never waste CPU on zstd again. The system **learns your data's shape** and adapts. If your data is random, Zenith stops trying.

### 🔥 6. Hot Key Cache

A 64-entry direct-mapped cache catches the **80/20 access pattern**. Most reads never touch the tree at all. Includes **negative caching** — keys that don't exist are also remembered, so repeated misses skip tree traversal entirely.

### 📈 7. Append Fast-Path

Monotonically increasing keys (time series, auto-increment IDs, bulk loads) **skip the binary search entirely**. Just append to the rightmost leaf. Zero search cost for sequential workloads.

### 🛡️ 8. CRC32C Corruption Detection

Every byte read from disk is verified with **hardware-accelerated CRC32C** (SSE 4.2 intrinsic). Bit rot, partial writes, and silent corruption are detected instantly.

### 📋 9. Atomic Metadata Batches

Three-phase flush protocol:
```
write data → fsync → commit ALL metadata as one atomic batch → fsync
```

**True 0-RPO crash recovery.** No partial visibility. No corruption. No ambiguity. If crash occurs between data write and metadata commit, the orphaned heap space is reclaimed — data integrity is never compromised.

### 🌿 10. Adaptive Leaf Compaction

After deletes, underfull leaves are **merged with their neighbors** — including recursive internal node rebalancing up to the root. The tree stays dense. Tree height stays minimal.

### 🔮 11. Predictive Scan Prefetch

During sequential reads, the next leaf's first cache line is **touched before the current leaf finishes processing**. DRAM latency is hidden behind computation. The scan doesn't stall.

### 🏷️ 12. Memory-Efficient Metadata Tagging

Size class information is **encoded into the bottom 6 bits of the slab slot offset** (all slots are 32+ byte aligned, so the bottom bits are always 0). **33% smaller metadata entries** — each entry is 16 bytes instead of 24.

### 🔫 13. Hot Path Inlining

All helper functions in the `get()`/`insert()`/`delete()` hot path are **manually inlined with direct unsafe pointer dereferences**. LLVM sees one flat function with zero opaque call boundaries. It schedules all loads in parallel, eliminates redundancies, and merges adjacent stores.

### 🔬 14. Benchmark-Grade Metrics

Every operation path is instrumented for timing. The hot cache tracks hit rates. The compression gating tracks savings. **Zenith knows its own performance** and adapts.

---

## 💪 Why Zeta Makes This Possible

| You Want... | C Database Does... | Zenith Does... |
|---|---|---|
| Fast allocation | `malloc()` per node | `ptr += 4096` from mmap slab |
| Size class lookup | Runtime while loop with multiply | Array index into CTFE-computed table |
| Key search | Binary search with branch mispredicts | SIMD 4-wide unrolled scan |
| Flush | `alloc` + `memcpy` + `write` + `free` | `pwrite` from arena (zero-copy) |
| Compression | Always compress, never learn | Adaptive gating per leaf |
| Crash recovery | WAL with complex rollback | Atomic metadata batch (simple, correct) |
| Memory tagging | Can't repurpose pointer bits | 6-bit size class in aligned offset |
| Syscall I/O | `#include <fcntl.h>` + C runtime | `syscall(2, path, flags, mode)` — pure language |
| Corruption detection | Separate CRC library | Inline SSE 4.2 intrinsic |

---

## 🔧 Building

```bash
git clone https://github.com/murphsicles/zenith.git
cd zenith
make test
```

Requires [Zeta](https://github.com/murphsicles/zeta) **v1.0.16+**.

## 📝 Usage

```zeta
use zenith::{Db, Config};

fn main() -> i64 {
    // 🧪 In-memory mode (no persistence)
    let config = Config::new().temporary(true);
    let db = Db::open(config);
    
    db.set(42, 100);
    db.set(43, 200);
    
    let val = db.get(42);        // → 100 ⚡
    let miss = db.get(999);      // → 0 (negative cached!)
    db.delete(43);               // → true ✅
    
    // 💾 Persistent mode
    let config = Config::new()
        .path("/data/zenith_db")
        .cache_size(1024 * 1024 * 100)   // 100MB cache
        .compression_level(3);            // zstd level 3
    let db = Db::open(config);
    
    db.set(1, 1000);
    db.flush();  // Atomic, crash-safe ✅
    
    0
}
```

## 📊 Expected Performance

| Operation | Time | Why |
|---|---|---|
| Cache hit read | ~3-5ns | No tree traversal 🏃 |
| Cache miss read | ~50-100ns | SIMD 4-wide B+ tree search ⚡ |
| Sequential insert | ~20-40ns | Append fast-path 📈 |
| Random insert | ~100-200ns | SIMD search + arena alloc 🎯 |
| Flush throughput | ~1-2 GB/s | Zero-copy arena→disk 📀 |
| Metadata overhead | 16 bytes/entry | Tagged offset 🏷️ |
| CRC verification | ~1ns/8 bytes | Hardware SSE 4.2 🛡️ |

## 📦 What's Inside

```
zenith/
├── src/
│   ├── alloc.z        # Arena + libc wrappers
│   ├── cache.z        # Clock-sweep LRU cache
│   ├── checksum.z     # CRC32C with CTFE table
│   ├── config.z       # CTFE-verified configuration
│   ├── db.z           # Database orchestrator
│   ├── flush.z        # Flush epoch pipeline
│   ├── heap.z         # Slab allocator (20% classes)
│   ├── id_alloc.z     # Atomic ID allocator
│   ├── metadata.z     # Atomic metadata batch store
│   ├── mod.z          # Root module + Error type
│   ├── node.z         # B+ tree nodes (all ops)
│   ├── sync/          # Lock-free stack + queue
│   ├── syscall.z      # Pure Zeta POSIX I/O (95 lines)
│   └── tree.z         # Lock-free B+ tree
├── tests/
│   └── test_zenith.zeta  # 10-test suite
└── Makefile
```

## 📜 License

MIT OR Apache-2.0 ⚡ Built with [Zeta](https://github.com/murphsicles/zeta)
