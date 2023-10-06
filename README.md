# tshare

The fastest way to share your local files on the web. Powered by [transfer.sh](https://transfer.sh)

![tshare](https://github.com/trikko/tshare/assets/647157/fd66bb95-a78c-41a6-bca6-e3ba736edcab)

# examples

minimal
```bash
tshare /path/to/file
```

keep file online for two days / max 10 downloads
```bash
tshare -t 2 -d 10 /path/to/file
```

encrypt with gpg if installed on your system
```bash
tshare -c your-secret-password /path/to/file
```

# install with homebrew

If you have ```homebrew``` on your MacOS/Linux, you can install ```tshare``` using a local formula:

```
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --build-from-source ./tshare.rb
```

You're done 🎉 

Run ```tshare -h```, star this repository and have fun. 

# build from source

_If you don't have homebrew_, you need a dlang compiler to compile tshare by yourself.

### install a dlang compiler
- Ubuntu: ```sudo apt install dub ldc libcurl-dev```
- macOS: ```brew install ldc dub```

*or* download an official package [here](https://dlang.org/download.html#dmd)

### compile tshare
```d
dub build
cp tshare /usr/local/bin
```
