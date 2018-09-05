* checkout  hugo

```
cd /tmp
wget https://github.com/gohugoio/hugo/releases/download/v0.42.1/hugo_0.42.1_Linux-64bit.tar.gz
tar -xvzf hugo_0.42.1_Linux-64bit.tar.gz
sudo mv hugo /usr/local/bin
hugo -version
``**


* create blog

*** create site
*** create them
** create content
cd themes && git clone https://github.com/spf13/hyde
git clone --depth 1 --recursive https://github.com/gohugoio/hugoThemes.git themes
