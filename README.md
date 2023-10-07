# tshare

The fastest way to share your local files on the web (Windows / Linux / macOS), for free. 

Powered by [transfer.sh](https://transfer.sh) online service.

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

# pre-builds binaries
[![Windows](https://img.shields.io/badge/-Windows_x64-blue.svg?style=for-the-badge&logo=windows)](https://github.com/trikko/tshare/releases/latest/download/tshare-windows-x86_64.zip)
[![Unix](https://img.shields.io/badge/-Linux-red.svg?style=for-the-badge&logo=linux)](https://github.com/trikko/tshare/releases/latest/download/tshare-linux-x86_64.zip)
[![MacOS](https://img.shields.io/badge/-MacOS-lightblue.svg?style=for-the-badge&logo=apple)](https://github.com/trikko/tshare/releases/latest/download/tshare-macos-x86_64.zip).

I didn't test the binaries so much: feedbacks are welcome :)

# install with homebrew (Linux, macOS)

If you have ```homebrew``` on your MacOS/Linux, you can install ```tshare``` using a local formula:

```
HOMEBREW_NO_INSTALL_FROM_API=1 brew install --build-from-source ./tshare.rb
```

You're done 🎉 

Run ```tshare -h```, star this repository and have fun. 

# build from source (Linux, macOS, Windows)

_If you don't have homebrew_, you need a dlang compiler to compile tshare by yourself.

### install a dlang compiler
- Ubuntu: ```sudo apt install dub ldc libcurl-dev```
- macOS: ```brew install ldc dub```
- Windows: *see below*
  
*or* 

download an official package [here](https://dlang.org/download.html#dmd)

### compile tshare
```d
dub build
cp tshare /usr/local/bin
```
