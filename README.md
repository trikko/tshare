# tshare

A simple CLI tool for [transfer.sh](https://transfer.sh)

![tshare](https://github.com/trikko/tshare/assets/647157/392cd79f-56ea-4674-90af-28b431dd2bcf)

# examples

minimal
```bash
tshare /path/to/file
```

keep file online for two days / max 10 downloads
```bash
tshare -t 2 -d 10 /path/to/file
```

# installation

Of course you need a [dlang compiler](https://dlang.org/download.html#dmd)

### build

```d
dub build tshare
```

### install (on Linux, MacOS, ...)
```bash
ln -s /usr/local/bin/tshare $PWD/tshare
```
