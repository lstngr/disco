# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs
export MODULEPATH="/discofs/$(whoami)/opt/software/modulefiles${MODULEPATH:+:$MODULEPATH}"
