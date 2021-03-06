#!/bin/sh

RUBY_VERSION=2.3.1
#NODE_VERSION=7.1.0

MACKUP_CONFIG_CORE="[storage]
engine = icloud"

MACKUP_CONFIG_SSH="[application]
name = SSH

[configuration_files]
.ssh"

cd `dirname $0`

echo -e "\033[31m
       .__  .__            __                .__
  ____ |  | |__|         _/  |_  ____   ____ |  |   ______
_/ ___\|  | |  |  ______ \   __\/  _ \ /  _ \|  |  /  ___/
\  \___|  |_|  | /_____/  |  | (  <_> |  <_> )  |__\___ \
 \___  >____/__|          |__|  \____/ \____/|____/____  >
     \/                                                \/
\033[0m\n"

#--- Permissions
echo -e "\033[1;4;34mChecking User Permissions...\033[0m\n"

if [ "$(whoami)" == "root" ]; then
	echo -n "You should not run this script as the root user!"
	exit 2
fi
echo -e "\033[32mOK\033[0m\n"

# Set GITHUB_TOKEN value in .bash_profile file
if grep -Fq "GITHUB_TOKEN" ~/.bash_profile
then
	echo -n "GITHUB_TOKEN already present in ${HOME}/.bash_profile, skipping."
else
	# Request user for their GitHub token so that various tools may access their GitHub account.
	echo -n "It is recommended that you configure a GitHub token for command line usage.  See https://help.github.com/articles/creating-an-access-token-for-command-line-use/ for information help with gnerating a token."
	echo -n "Please enter your GitHub token followed by [ENTER]:"
	read GITHUB_TOKEN

	echo -n "export GITHUB_TOKEN='$GITHUB_TOKEN'" >> ~/.bash_profile
fi

echo # Insert blank line for legibility

if [ "$(uname)" == "Darwin" ]; then
	# Do something under Mac OS X platform
	#source ./environment/osx.sh

	# Show hidden files in Finder
	defaults write com.apple.finder AppleShowAllFiles YES

	# Install X-Code Command Line Tools
	xcode-select --install

	# Uninstall MacPorts
	echo -e "\033[1;4;34mChecking MacPorts installation status...\033[0m\n"

	hash port &> /dev/null
	if [ $? -eq 1 ]; then
		echo -e "\033[32mMacPorts not found.  Proceeding...\033[0m\n"
	else
		echo -e "\033[1;4;31mWARNING.\033[0m  This script will attempt to uninstall MacPorts and everything that has been installed via MacPorts.  Would you like to continue anyway?\n"
		#echo $'WARNING.  This script will attempt to uninstall MacPorts and everything that has been installed via MacPorts.  Would you like to continue anyway?\n'
		read CONTINUE
		if [ $CONTINUE = 'yes' ] || [ $CONTINUE = 'y' ]; then
			echo $'You have been warned!  MacPorts will now be uninstalled.\n'
			sudo port -f uninstall installed
			sudo rm -rf /opt/local
			sudo rm -rf /Applications/DarwinPorts
			sudo rm -rf /Applications/MacPorts
			sudo rm -rf /Library/LaunchDaemons/org.macports.*
			sudo rm -rf /Library/Receipts/DarwinPorts*.pkg
			sudo rm -rf /Library/Receipts/MacPorts*.pkg
			sudo rm -rf /Library/StartupItems/DarwinPortsStartup
			sudo rm -rf /Library/Tcl/darwinports1.0
			sudo rm -rf /Library/Tcl/macports1.0
			sudo rm -rf ~/.macports
		else
			echo $'Aborting configuration process.\n'
			exit
		fi
	fi

	# Configure Homebrew
	hash brew &> /dev/null
	if [ $? -eq 1 ]; then
		echo $'Homebrew not found.  Installing...\n'
		ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
		brew doctor
	else
		HOMEBREW_PATH=$(which brew)
		HOMEBREW_PATH_MATCH=$(awk 'BEGIN { print index("${PATH}", "${HOMEBREW_PATH}") }')
		HOMEBREW_CELLAR_PATH=$(brew --cellar)
		HOMEBREW_UTILITY_PATH='/usr/local/bin'
		HOMEBREW_UTILITY_PATH_MATCH=$(awk -v PATH=$PATH -v HOMEBREW_UTILITY_PATH=$HOMEBREW_UTILITY_PATH 'BEGIN { print index(PATH, HOMEBREW_UTILITY_PATH) }')

		 if [ ${HOMEBREW_UTILITY_PATH_MATCH} -eq 0 ] ; then
			 echo $'Homebrew is installed at the following path:'
			 echo $HOMEBREW_UTILITY_PATH$'\n'

			 echo $'Your Homebrew utility directory is not available on the system path:\n'
			 echo $PATH$'\n'
			 echo $'Would you like to add the Homebrew utility directory to your system path?'

			 read CONTINUE
			 if [ $CONTINUE = 'yes' ] || [ $CONTINUE = 'y' ]; then
				 export PATH=$HOMEBREW_UTILITY_PATH":"$PATH
				 echo -n "export PATH=\"${HOMEBREW_UTILITY_PATH}:$PATH\"" >> .bash_profile
				 echo $'Your PATH environment variable is now set to.'$PATH$'\n'
			 else
				 echo $'Aborting build process.\n'
				 exit
			 fi
		 fi

		#HOMEBREW_STATUS=$(brew doctor)
		#echo $HOMEBREW_STATUS$'\n'

		brew doctor

		echo $'Pruning broken symlinks.\n'
		brew prune

		echo $'Removing old versions of installed packages.\n'
		brew cleanup

		echo $'Updating Homebrew.\n'
		brew update

		echo $'Installing missing dependancies.\n'
		brew install $(brew missing | cut -d' ' -f2- )

		echo $'Listing outdated Homebrew formulae.\n'
		brew outdated

		echo $'Upgrading outdated Homebrew formulae.\n'
		brew upgrade --all

		echo $'Unlinking and re-linking all formulas and kegs.\n'
		ls -1 /usr/local/Library/LinkedKegs | while read line; do echo $line; brew unlink $line; brew link --force $line; done
		brew list -1 | while read line; do brew unlink $line; brew link $line; done

		HOMEBREW_STATUS=$(brew doctor)

		echo $HOMEBREW_STATUS$'\n'

		if [ "$HOMEBREW_STATUS" != 'Your system is ready to brew.' ]; then
			echo $'You have an error or warning with your Homebrew installation that must be resolved before this build process can continue.'
			echo $'Please ensure that your system is ready to brew.\n'
			exit
		else
			echo $'System is ready to brew.\n'
		fi
	fi
	echo -e "\033[32mOK\033[0m\n"

	# Homebrew Notifier - Notifies you when homebrew package updates are available
	curl -fsS https://raw.githubusercontent.com/grantovich/homebrew-notifier/master/install.sh | sh

	# Install Brew Cask via Homebrew
	#brew install caskroom/cask/brew-cask
	brew tap caskroom/cask

	# Update and cleanup Homebrew Cask
	#brew upgrade brew-cask && brew cask cleanup

	brew tap caskroom/versions

	# Install XQuartz
	#brew cask install xquartz
	brew install Caskroom/cask/xquartz

	# source updated .bash_profile file
	source ~/.bash_profile

	# Install pip package management system which is used to install and manage software packages written in Python.
	sudo easy_install pip
	#easy_install pip

	# brew tap allows you to import formula from other repositories into your Homebrew instance.
	#brew tap homebrew/apache
	brew tap homebrew/dupes
	brew tap homebrew/versions

	# Set Homebrew options

	# Verify
	brew update && brew upgrade

	# Install Homebrew formulae for command line applications
	brew install autoconf
	brew install awscli
	brew install batik
# 	brew install boot2docker
# 	brew install bradp/vv/vv
	brew install coreutils
	brew install dnsmasq
# 	brew install docker
# 	brew install docker-compose
	brew install faac
	brew install ffmpeg --with-faac --with-fdk-aac --with-ffplay --with-freetype --with-libass --with-libquvi --with-libvorbis --with-libvpx --with-opus --with-x265
	brew install fontforge
	brew install git
	brew install git-extras
	brew install git-flow-avh
	brew install git-lfs
	brew install gh
	brew install gmp # ruby needs this, not sure why
# 	brew install gnu-getopt
	brew install gpg
	brew install graphicsmagick
	brew install imagemagick
	brew install lynx
	brew install mackup
	brew install mariadb
	brew install mas
# 	brew install mongodb
# 	brew install mysql
	brew install node
	brew install nodeenv
	brew install openssl
	brew install pkg-config
	brew install rbenv
	brew install readline
# 	brew install redis
	brew install ruby-build
	brew install shellcheck
	brew install ssh-copy-id
	brew install terraform
	brew install ttf2eot
	brew install wget

	# Install defined Ruby version via rbenv
	rbenv install $RUBY_VERSION

	# Set defined Ruby version as the default version
	rbenv global $RUBY_VERSION

	# Installs shims for all Ruby executables known to rbenv
	rbenv rehash

	# Check environment ruby is using the latest version installed by rbenv
	ruby -v

	# Tap Apache
	brew tap homebrew/apache

	# Tap PHP
#	brew tap homebrew/homebrew-php
	brew tap homebrew/php

	# Stop stock Apache and prevent it from loading on system start
	sudo apachectl stop
	sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist 2>/dev/null
	
	# Install Apache
	brew install httpd24 --with-privileged-ports --with-http2

	#brew install php56
	#brew unlink php56

	brew install php56 --with-apache
	brew install php56-xdebug
	brew install xdebug-osx

	php -i | grep xdebug

	#brew install php71
	#brew unlink php71

	# Add Apache launch daemon
	sudo cp -v /usr/local/Cellar/httpd24/2.4.23_2/homebrew.mxcl.httpd24.plist /Library/LaunchDaemons
	sudo chown -v root:wheel /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
	sudo chmod -v 644 /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist
	sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.httpd24.plist

	brew install brew-php-switcher

	brew-php-switcher 71

# 	xdebug.remote_enable=1
# 	xdebug.remote_host=127.0.0.1
# 	xdebug.remote_connect_back=1    # Not safe for production servers
# 	xdebug.remote_port=9000
# 	xdebug.remote_handler=dbgp
# 	xdebug.remote_mode=req
# 	xdebug.remote_autostart=true

	xdebug-toggle on

	#brew install php56 --homebrew-apxs --with-apache --with-homebrew-curl --with-homebrew-openssl --with-phpdbg --with-tidy --without-snmp
	#chmod -R ug+w /usr/local/Cellar/php56/5.6.9/lib/php
	#pear config-set php_ini /usr/local/etc/php/5.6/php.ini
	#printf '\nAddHandler php5-script .php\nAddType text/html .php' >> /usr/local/etc/apache2/2.4/httpd.conf
	#perl -p -i -e 's/DirectoryIndex index.html/DirectoryIndex index.php index.html/g' /usr/local/etc/apache2/2.4/httpd.conf
	#printf '\nexport PATH="$(brew --prefix homebrew/php/php56)/bin:$PATH"' >> ~/.profile
	#echo 'export PATH="$(brew --prefix php56)/bin:$PATH"' >> ~/.bash_profile
	#ln -sfv /usr/local/opt/php56/*.plist ~/Library/LaunchAgents
	#brew install php-version

	brew install homebrew/php/composer # install here to avoid unsatisfied requirement failure
	brew install homebrew/php/php-cs-fixer
	brew install wp-cli
	
	# Configure Dnsmasq

	# Copy the default configuration file.
	cp $(brew list dnsmasq | grep /dnsmasq.conf.example$) $(brew --prefix)/etc/dnsmasq.conf
	
	# Add entry for .dev TLD
	echo "local=/dev/" >> $(brew --prefix)/etc/dnsmasq.conf
	echo "address=/.dev/127.0.0.1" >> $(brew --prefix)/etc/dnsmasq.conf
	
	# Copy the daemon configuration file into place.
	sudo cp $(brew list dnsmasq | grep /homebrew.mxcl.dnsmasq.plist$) /Library/LaunchDaemons/

	# Start Dnsmasq automatically.
	sudo launchctl load /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist
		
	# Start dnsmasque
	#sudo launchctl stop homebrew.mxcl.dnsmasq
	sudo launchctl start homebrew.mxcl.dnsmasq

	# CREATE A new DNS resolver instance
	sudo mkdir -v /etc/resolver
	sudo bash -c 'echo "nameserver 127.0.0.1" > /etc/resolver/dev'
	sudo bash -c 'echo "domain dev" > /etc/resolver/dev'
	sudo bash -c 'echo "search_order 1" > /etc/resolver/dev'

	# Flush DNS cache
	dscacheutil -flushcache

	# Allow VHost access
	sudo bash -c 'echo "pass in proto tcp from any to any port 80" >> /etc/pf.conf'

	# Load Apache config from Mackup
	#sudo mv /etc/apache2/httpd.conf /etc/apache2/httpd.bak
	sudo cp $(brew --prefix)/etc/apache2/2.4/httpd.conf $(brew --prefix)/etc/apache2/2.4/httpd.conf.bak.orig
	#echo "Include /Users/karl/.apache2/httpd.conf" | sudo tee -a /etc/apache2/httpd.conf > /dev/null

	sed -i.bak "s|Listen 8080|Listen 80|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|User daemon|User karl|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|Group daemon|Group staff|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|you@example.com|karl.podger@primeordinal.com|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|#LoadModule vhost_alias_module libexec/mod_vhost_alias.so|LoadModule vhost_alias_module libexec/mod_vhost_alias.so|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|#LoadModule rewrite_module libexec/mod_rewrite.so|LoadModule rewrite_module libexec/mod_rewrite.so|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|AllowOverride none|AllowOverride all|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|/usr/local/var/www/htdocs|/Users/karl/Sites|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	#sed -i.bak "s|DirectoryIndex index.html|DirectoryIndex index.html index.php|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	#sed -i.bak "s|#Include /usr/local/etc/apache2/2.4/extra/httpd-vhosts.conf|Include /Users/karl/.apache2/extra/httpd-vhosts.conf|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	sed -i.bak "s|LoadModule php|#LoadModule php|g" $(brew --prefix)/etc/apache2/2.4/httpd.conf
	echo "LoadModule php5_module /usr/local/opt/php56/libexec/apache2/libphp5.so" | tee -a $(brew --prefix)/etc/apache2/2.4/httpd.conf > /dev/null
	echo "LoadModule php7_module /usr/local/opt/php71/libexec/apache2/libphp7.so" | tee -a $(brew --prefix)/etc/apache2/2.4/httpd.conf > /dev/null
	echo "Include /Users/karl/.apache2/extra/httpd-vhosts.conf" | tee -a $(brew --prefix)/etc/apache2/2.4/httpd.conf > /dev/null
	echo "Include /Users/karl/.apache2/other/php.conf" | tee -a $(brew --prefix)/etc/apache2/2.4/httpd.conf > /dev/null
	
	# Quick Look plugins, see https://github.com/sindresorhus/quick-look-plugins
	brew cask install qlcolorcode qlstephen qlmarkdown quicklook-json qlprettypatch quicklook-csv betterzipql qlimagesize webpquicklook suspicious-package

	# Create logs for default virtual host
	mkdir -p ~/Sites/_logs
	touch ~/Sites/_logs/access.log
	touch ~/Sites/_logs/error.log

	# Create default site
	mkdir -p ~/Sites/default_site
	sudo bash -c 'echo "<html lang="en"><head><meta charset="utf-8" /><title>Default site</title></head><body><h1>Default site</h1></body></html>" >>  ~/Sites/default_site/index.html'

	# Test and restart Apache
	sudo apachectl -tS
	sudo apachectl restart

	# Show configuration
	dig default_site.dev @127.0.0.1
	host default_site.dev 127.0.0.1
	ping -c 1 default_site.dev

	scutil --dns

	# Install Homebrew cask formulae for GUI-based applications
	brew cask install atom
	brew cask install cakebrew
	brew cask install chromium
	brew cask install deltawalker
	brew cask install docker
	#brew cask install dockertoolbox
	brew cask install docker-toolbox
	#brew cask install dropbox
	brew cask install firefox
	brew cask install flux
	#brew cask install github
	brew cask install github-desktop
	brew cask install google-chrome
	brew cask install google-chrome-canary
	brew cask install google-cloud-sdk
	brew cask install handbrake
	brew cask install handbrakecli
	brew cask install hyperdock
	brew cask install iexplorer
	brew cask install iterm2
	brew cask install mysqlworkbench
	brew cask install openemu
	brew cask install sequel-pro
	brew cask install skype
	brew cask install steam
	brew cask install tower
	brew cask install transmit
	#brew cask install virtualbox #ordering!
	#brew cask install vagrant
	#brew cask install vagrant-manager
	brew cask install vlc

	mas install 497799835 #Xcode
	mas install 824171161 #Affinity Designer
	mas install 409183694 #Keynote
	mas install 425424353 #The Unarchiver
	mas install 405580712 #StuffIt Expander
	mas install 412448059 #ForkLift
	mas install 463541543 #Gemini
# 	mas install 411246225 #Caffeine
	mas install 937984704 #Amphetamine
	mas install 882812218 #Owly
	mas install 408981434 #iMovie
	mas install 803453959 #Slack
	mas install 409201541 #Pages
	mas install 407963104 #Pixelmator
	mas install 963642514 #Duplicate Photos Fixer Pro
	mas install 682658836 #GarageBand
	mas install 404010395 #TextWrangler
	mas install 409203825 #Numbers
	mas install 897118787 #Shazam
	mas install 447513724 #Smart Converter

	#echo "$MACKUP_CONFIG_CORE" > ~/.mackup.cfg
  	#echo "$MACKUP_CONFIG_SSH" > ~/.mackup/ssh.cfg

	# create boot2docker vm
	#boot2docker init

	# vm needs to be powered off in order to change these settings without VirtualBox blowing up
	#boot2docker stop > /dev/null 2>&1

	# Downloading latest boot2docker ISO image
	#boot2docker upgrade

	# forward default docker ports on vm in order to be able to interact with running containers
	#echo -n 'eval "$(boot2docker shellinit)"' >> ~/.bash_profile

elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
	# Do something under Linux platform
	LSB_RELEASE=/etc/lsb-release

	if [ -f LSB_RELEASE ]; then
		DISTRIB_ID=`cat LSB_RELEASE | sed -n 's/^DISTRIB_ID=//p'`
	fi

	echo -n "DISTRIB_ID: $DISTRIB_ID"

	if [[ $DISTRIB_ID = 'Ubuntu' ]]; then
		#bash ./environment/ubuntu.sh

		# Update apt-get packages list
		sudo apt-get update

		# Upgrade installed apt-get packages
		sudo apt-get upgrade

		# Install packages using apt-get
		sudo apt-get install build-essential ruby-full rubygems-update git npm mongodb imagemagick graphicsmagick

		# Update gem via gem
		sudo update_rubygems

		# Install cli utilities via pip
		sudo pip install awscli --upgrade
		sudo pip install docker-compose --upgrade
	else
		echo -n "Please update this file to work with the package manager for this distribution"
	fi

elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
	# Do something under Windows NT platform
	echo -n "LOL Windows"
	exit
fi

# Set NODE_ENV value in .bash_profile file
if grep -Fxq "NODE_ENV" ~/.bash_profile
then
	# code if found
	echo -n "NODE_ENV already present in ${HOME}/.bash_profile, skipping."
else
	# code if not found
	echo -n "export NODE_ENV=development" >> ~/.bash_profile
fi

# Install Composer globally # install via brew
#mkdir -p /usr/local/bin
#curl -sS https://getcomposer.org/installer | php
#mv composer.phar /usr/local/bin/composer

# Update gem via gem
gem update --system

# Install cli utilities via gem
#gem install bundler
#gem install sass
#gem install scss_lint
gem install travis -v 1.8.2 --no-rdoc --no-ri

# Install php-cs-fixer via Composer
#composer global require fabpot/php-cs-fixer
#composer global require friendsofphp/php-cs-fixer
#echo -n "export PATH=\"$PATH:$HOME/.composer/vendor/bin\"" >> .bash_profile

# Clear npm cache
npm cache clean -f

# Update npm via npm
sudo npm update -g npm

# Install n node version manager via npm
#npm install -g n

# Install latest development version of node using n
#sudo n latest

# Check environment node is using the latest version installed by n
node -v

# Install cli utilities globally via npm
npm install -g babel-cli
npm install -g babel-eslint
npm install -g bower
#npm install -g bower-check-updates
#npm install -g browser-sync
#npm install -g cordova
npm install -g csscomb
npm install -g eslint
npm install -g firebase-tools
npm install -g grunt-cli
npm install -g gulp
#npm install -g harp
#npm install -g ionic
#npm install -g imagemin
#npm install -g istanbul
npm install -g js-beautify
npm install -g jscs
npm install -g jshint
npm install -g jsonlint
npm install -g manifoldjs
#npm install -g mocha
#npm install -g node-inspector
npm install -g npm-check-updates
#npm install -g npm-update-all
#npm install -g npmedge
#npm install -g pm2
#npm install -g polylint
npm install -g polymer-cli
npm install -g prettydiff
#npm install -g scss-lint
#npm install -g strongloop
npm install -g tslint
npm install -g typescript-formatter
npm install -g unused-deps
npm install -g yo

# Install Yeoman generators via npm
npm install -g generator-generator
#npm install -g generator-webapp

# Set git to respect case sensitivity (particularly relevant for OS-X)
git config core.ignorecase false

# Install Atom packages via apm
apm install atom-change-case
apm install angularjs
apm install atom-autocomplete-wordpress-hooks
apm install atom-beautify
apm install atom-typescript
apm install atom-wallaby
apm install autocomplete-php
apm install autocomplete-sass
apm install autoprefixer
apm install build
apm install build-gulp
apm install caniuse
apm install clipboard-history
#apm install code-links
apm install color-picker
apm install console-log
apm install css-snippets
apm install csscomb
apm install emmet
apm install file-icons
apm install gulp-helper
apm install ionic-atom
apm install js-hyperclick
apm install jscs-fixer
#apm install jsformat
apm install language-docker
apm install language-ejs
apm install linter
apm install linter-csslint
apm install linter-htmlhint
apm install linter-jscs
apm install linter-jshint
apm install linter-jsonlint
apm install linter-less
apm install linter-php
apm install linter-puppet-lint
apm install linter-sass-lint
#apm install linter-scss-lint
apm install linter-shellcheck
apm install linter-tidy
apm install linter-tslint
apm install local-history
apm install merge-conflicts
apm install minimap
apm install minimap-bookmarks
apm install minimap-codeglance
apm install minimap-find-and-replace
apm install minimap-git-diff
apm install minimap-highlight-selected
apm install minimap-linter
apm install minimap-pigments
apm install minimap-selection
apm install npm-install
apm install php-cs-fixer
apm install php-debug
apm install pigments
apm install polymer-snippets
apm install project-manager
apm install tabs-to-spaces
apm install travis-ci-status
apm install symbols-tree-view
apm install Sublime-Style-Column-Selection
apm install wordpress-api
apm install zp-acf-snippets

# Update Atom packages via apm
apm update

# Install Vagrant plugins via vagrant
#vagrant plugin install vagrant-hostsupdater
#vagrant plugin install vagrant-triggers

# curl https://sdk.cloud.google.com | bash

# source updated .bash_profile file
source ~/.bash_profile

# Check if rbenv was set up
type rbenv

# List globally installed npm packages
npm list -g --depth=0

# List installed apm packages
apm list --installed --bare

# open https://itunes.apple.com/en/app/xcode/id497799835?mt=12

# echo -n "Further (manual) configuration:"

# echo -n "https://itunes.apple.com/en/app/xcode/id497799835?mt=12"
# echo -n "https://github.com/leogopal/VVV-Dashboard"

# Restart shell, see https://cloud.google.com/sdk/#Quick_Start
exec -l $SHELL

exit
