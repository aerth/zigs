# some zigs

### compiling

run `zig build`

look in the `zig-out` directory (change install dir with -p flag)

try `make example`


### usage

## Integrating Zigs in your Project
### Zig Package Manager
In the `build.zig.zon` file, add the following to the dependencies object.

(replace b558.. with some git hash)

```zig
.zigs = .{
    .url = "https://github.com/aerth/zigs/archive/b558fa51b28304101917fdfc6728735f4b426eda.tar.gz",
}
```

The compiler will produce a hash mismatch error, add the `.hash` field to `build.zig.zon`
with the hash the compiler tells you it found.

Then in your `build.zig` file add the following to the `exe` section for the executable where you wish to have Zigs available.

```zig
const zigs = b.dependency("zigs", .{
    .optimize = optimize,
    .target = target,
});
// for exe, lib, tests, etc.
exe.addModule("zigs", zigs.module("zigs"));
```

Now in the code, you can import components like this:

```zig
const zigs = @import("zigs");
const networking = zigs.networking;
```
