# tshare

A simple CLI tool for [transfer.sh](https://transfer.sh)

![tshare](https://github.com/trikko/tshare/assets/647157/65a2e5c4-3614-409d-a66f-54aac57f7688)

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

If you have ```homebrew``` on your MacOS/Linux, you can install ```tshare``` using a local formula:

```
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --build-from-source ./tshare.rb
```

# build from source

Of course you need a [dlang compiler](https://dlang.org/download.html#dmd), then:

```d
dub build tshare
```

### install (on Linux, MacOS, ...)
```bash
cp tshare /usr/local/bin
```
