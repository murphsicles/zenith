# Zenith — The Zeta-native Database

**The world's fastest, most efficient in-memory database, built from first principles in Zeta.**

Zenith is a lock-free, transactional embedded database with:
- Lock-free B+ tree indexing
- Atomic metadata batches (no WAL, no LSM)
- Zstd-compressed on-disk persistence
- Scan-resistant LRU caching
- Slab-based heap allocation (~20% size increments)
- Epoch-based reclamation

Architecture inspired by [sled](https://github.com/spacejam/sled), written Zeta-native.

## Status

🚧 Early development — transpiling Sled's architecture into Zeta-idiomatic code.

## Building

```
zetac build
```

## Usage

```zeta
use zenith::{Db, Config, Tree};

fn main() -> i64 {
    let config = Config::new()
        .path("/tmp/zenith_db")
        .cache_size(1024 * 1024 * 100)  // 100MB cache
        
    let db = Db::open(config);
    let tree = db.open_tree("default");
    
    tree.set("hello".bytes(), "world".bytes());
    let val = tree.get("hello".bytes());
    
    db.flush();
    return 0;
}
```

## License

MIT OR Apache-2.0
