# dotapps

```
       __      __                        
  ____/ /___  / /_____ _____  ____  _____
 / __  / __ \/ __/ __ `/ __ \/ __ \/ ___/
/ /_/ / /_/ / /_/ /_/ / /_/ / /_/ (__  ) 
\__,_/\____/\__/\__,_/ .___/ .___/____/  
                    /_/   /_/            
```

This repository contains a script designed to automate the setup of a consistent application environment across different systems. Additionally, it places necessary files automatically based on specified dotfiles.

## Features

- __Consistent Environment Setup:__ Ensures the same application environment is constructed across various systems.
- __Automatic dotfiles Configuration:__ Automatically places required files according to specified dotfiles.

## Installation

### Using curl

```
sh -c "$(curl -fsLS https://raw.githubusercontent.com/kaduhiro/dotapps/main/etc/install.sh)"
```

### Using git

```
git clone https://github.com/kaduhiro/dotapps ~/.dotapps
sh ~/.dotapps/etc/install.sh
```

## Author

[Twitter](https://twitter.com/kaduhiro_)

## License

[MIT](https://en.wikipedia.org/wiki/MIT_License)

