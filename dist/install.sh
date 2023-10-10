# To keep separated from curl log
echo ""

case "$OSTYPE" in
   linux*) PACKAGE="linux.tar.gz";;
   darwin*) PACKAGE="macos.tar.gz";;
   win*)
      echo "auto-install not supported on windows. Download package here: https://tshare.download/windows.zip"
      return 1
      ;;
   *)
      echo "$OSTYPE auto-install not supported."
      return 1
      ;;
esac

paths=$(echo $PATH | tr ":" "\n")

bin_candidate=( "$HOME/.local/bin" "$HOME/.bin" "$HOME/bin" "/usr/local/bin" )
user_bin_dirs=( )
sudo_bin_dirs=( )

# Which dir is writable?
for p in ${bin_candidate[@]}; do

   if [[ ${paths[@]} =~ $p ]]
   then
      if [[ -w $p ]]
      then
         user_bin_dir+=($p)
      else
         sudo_bin_dir+=($p)
      fi;
   fi;

done;

# Trying user dir
if [[ ${#user_bin_dir[@]} -gt 0 ]]
then
   curl -sLo - "https://tshare.download/$PACKAGE" | tar xz -C ${user_bin_dir[0]}

   if [[ $? -eq 0 ]]
   then
      echo "Installed: '${user_bin_dir[0]}/tshare'"
      exit 0
   else
      echo "Installation fail"
      exit 1
   fi;
fi;

# System dir
if [[ ${#sudo_bin_dir[@]} -gt 0 ]]
then
   echo "tshare will be installated in '${sudo_bin_dir[0]}'"
   curl -sLo - "https://tshare.download/$PACKAGE" | sudo -k tar xz -C ${sudo_bin_dir[0]}

   if [[ $? -eq 0 ]]
   then
      echo "Installed: '${sudo_bin_dir[0]}/tshare'"
      exit 0
   else
      echo "Installation fail"
      exit 1
   fi;
fi;

echo "Can't find a directory to install tshare. Please report this issue."
echo "You can download the binary package here: https://tshare.download/$PACKAGE"
exit 1